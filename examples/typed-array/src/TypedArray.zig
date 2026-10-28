const std = @import("std");

const ArrayBuffer = @import("ArrayBuffer.zig");
const php = @import("php/root.zig");
const Array = php.Array;
const List = php.List;
const Object = php.Object;
const String = php.String;
const Value = php.Value;

pub fn @"fn"(comptime T: type, comptime options: struct {
    clamped: bool = false,
}) type {
    return struct {
        pub fn init(args: struct {
            any: ?union(enum) {
                length: usize,
                buffer: *ArrayBuffer,
                array: *TypedArray,
                list: []const T,
            },
            byte_offset: ?usize,
            length: ?usize,
        }) !@This() {
            const buffer: *Object = init: {
                if (args.any) |arg0| {
                    switch (arg0) {
                        .length => |len| {
                            // received a length--create an empty buffer
                            const ab: ArrayBuffer = .init(.{ .length = len * @sizeOf(T) });
                            break :init .createCustom(ArrayBuffer, ab);
                        },
                        .buffer => |ab| {
                            // received a buffer
                            break :init Object.fromCustom(ab).retain();
                        },
                        .array => |ta| {
                            // received a typed array of the same type--create a buffer
                            // and copy the contents
                            const src = try ta.getElements();
                            const ab: ArrayBuffer = .init(.{ .length = src.len * @sizeOf(T) });
                            const dest = ab.getElements(T, 0, ta.length) catch unreachable;
                            @memcpy(dest, src);
                            break :init .createCustom(ArrayBuffer, ab);
                        },
                        .list => |li| {
                            // received a regular array or an array-like object
                            var ab: ArrayBuffer = .init(.{ .length = li.len * @sizeOf(T) });
                            errdefer ab.deinit();
                            const dest = ab.getElements(T, 0, li.len) catch unreachable;
                            for (li, 0..) |value, i| dest[i] = value;
                            break :init .createCustom(ArrayBuffer, ab);
                        },
                    }
                } else {
                    const ab: ArrayBuffer = .init(.{ .length = 0 });
                    break :init .createCustom(ArrayBuffer, ab);
                }
            };
            const ab = buffer.custom(ArrayBuffer);
            const offset = args.byte_offset orelse 0;
            const len = init: {
                if (args.length) |len| {
                    if (offset + len * @sizeOf(T) > ab.length) return error.OutOfBound;
                    break :init len;
                } else {
                    if (offset > ab.length) return error.OutOfBound;
                    break :init (ab.length - offset) / @sizeOf(T);
                }
            };
            return .{
                .buffer = buffer,
                .offset = offset,
                .length = len,
            };
        }

        pub fn deinit(self: *@This()) void {
            self.buffer.release();
        }

        pub fn getElements(self: *@This()) ![]T {
            const ab = self.buffer.custom(ArrayBuffer);
            return try ab.getElements(T, self.offset, self.length);
        }

        pub fn getProperties(self: *@This(), purpose: Object.PropertiesPurpose) !?*Array {
            const elements = try self.getElements();
            if (purpose != .debug) return null;
            const arr: *Array = .create();
            const items_arr: *Array = .create();
            for (elements, 0..) |element, i| {
                if (i == 50) {
                    const remaining = elements.len - i;
                    if (remaining > 1) {
                        var buffer: [128]u8 = undefined;
                        const text = try std.fmt.bufPrint(&buffer, "... {d} more items", .{remaining});
                        const text_value: Value = .fromString(.create(text));
                        items_arr.append(text_value);
                        break;
                    }
                }
                items_arr.append(.fromAny(element));
            }
            arr.set("[ITEMS]", .fromArray(items_arr));
            // don't show items of ArrayBuffer
            ArrayBuffer.bytes_debug_output = false;
            return arr;
        }

        pub fn readDimension(self: *@This(), key: Value, _: Value.Access) !Value {
            const elements = try self.getElements();
            const index = try key.getUnsigned();
            if (index >= elements.len) return error.OutOfBound;
            return .fromAny(elements[index]);
        }

        pub fn writeDimension(self: *@This(), key: Value, value: Value) !void {
            const elements = try self.getElements();
            const index = try key.getUnsigned();
            if (index >= elements.len) return error.OutOfBound;
            if (options.clamped) {
                const int = try value.getInteger();
                elements[index] = if (int < std.math.minInt(T))
                    std.math.minInt(T)
                else if (int > std.math.maxInt(T))
                    std.math.maxInt(T)
                else
                    @intCast(int);
            } else {
                elements[index] = try value.convertTo(T);
            }
        }

        pub fn iterate(self: *@This()) Iterator {
            return .init(self);
        }

        pub const Iterator = struct {
            pub fn init(array: *TypedArray) @This() {
                Object.fromCustom(array).addRef();
                return .{ .array = array };
            }

            pub fn deinit(self: *@This()) void {
                Object.fromCustom(self.array).release();
            }

            pub fn next(self: *@This()) !?T {
                const elements = try self.array.getElements();
                if (self.index >= elements.len) return null;
                defer self.index += 1;
                return elements[self.index];
            }

            array: *TypedArray,
            index: usize = 0,
        };

        pub const @"export BYTES_PER_ELEMENT" = @sizeOf(T);

        pub fn @"get buffer"(self: *@This()) *Object {
            return self.buffer;
        }
        pub fn @"get byteLength"(self: *@This()) usize {
            return self.length * @sizeOf(T);
        }
        pub fn @"get byteOffset"(self: *@This()) usize {
            return self.offset;
        }
        pub fn @"get length"(self: *@This()) usize {
            return self.length;
        }

        pub fn @"call at"(self: *@This(), args: struct {
            index: isize,
        }) !?T {
            const elements = try self.getElements();
            const index = self.toAbsoluteIndex(args.index) catch return null;
            return elements[index];
        }

        pub fn @"call includes"(self: *@This(), args: struct {
            search_element: T,
            from_index: isize = 0,
        }) !bool {
            const elements = try self.getElements();
            const from = self.toAbsoluteIndex(args.from_index) catch return false;
            const result = std.mem.findScalarPos(T, elements, from, args.search_element);
            return result != null;
        }

        pub fn @"call indexOf"(self: *@This(), args: struct {
            search_element: T,
            from_index: isize = 0,
        }) !isize {
            const elements = try self.getElements();
            const from = self.toAbsoluteIndex(args.from_index) catch return -1;
            const result = std.mem.findScalarPos(T, elements, from, args.search_element);
            return if (result) |i| @intCast(i) else -1;
        }

        pub fn @"call lastIndexOf"(self: *@This(), args: struct {
            search_element: T,
            from_index: ?isize = null,
        }) !isize {
            const elements = try self.getElements();
            const from = if (args.from_index) |i|
                self.toAbsoluteIndex(i) catch return -1
            else
                elements.len - 1;
            const result = std.mem.findScalarLast(T, elements[0 .. from + 1], args.search_element);
            return if (result) |i| @intCast(i) else -1;
        }

        pub fn @"call reverse"(self: *@This(), _: struct {}) !*Object {
            const elements = try self.getElements();
            std.mem.reverse(T, elements);
            return Object.fromCustom(self);
        }

        pub fn @"call set"(self: *@This(), args: struct {
            source: union(enum) {
                array: *TypedArray,
                list: []const T,
            },
            offset: usize,
        }) !void {
            const dest = try self.getElements();
            const src: []const T = switch (args.source) {
                .array => |ta| try ta.getElements(),
                .list => |li| li,
            };
            if (args.offset + src.len > dest.len) return error.OutOfBound;
            @memcpy(dest[args.offset .. args.offset + src.len], src);
        }

        pub fn @"call sort"(self: *@This(), _: struct {}) !*Object {
            const elements = try self.getElements();
            std.mem.sortUnstable(T, elements, {}, std.sort.asc(T));
            return Object.fromCustom(self);
        }

        fn toAbsoluteIndex(self: *@This(), i: isize) !usize {
            return switch (i >= 0) {
                true => switch (@as(usize, @intCast(i)) < self.length) {
                    true => @as(usize, @intCast(i)),
                    false => error.OutOfBound,
                },
                // negative indice count from the end
                false => switch (@as(usize, @intCast(-i)) < self.length) {
                    true => self.length - @as(usize, @intCast(-i)),
                    false => error.OutOfBound,
                },
            };
        }

        const TypedArray = @This();

        buffer: *Object,
        length: usize,
        offset: usize,
    };
}
