const std = @import("std");

pub const Iterator = @import("Dictionary/Iterator.zig");
const php = @import("root.zig");
const Array = php.Array;
const Object = php.Object;
const String = php.String;
const N = String.static;
const php_al = php.allocator;
const Value = php.Value;
const failure = php.failure;

pub const @"union" = union(enum) {
    pub fn addRef(self: @This()) void {
        return switch (self) {
            .array => |arr| arr.addRef(),
            .object => |obj| obj.addRef(),
        };
    }

    pub fn release(self: @This()) void {
        return switch (self) {
            .array => |arr| arr.release(),
            .object => |obj| obj.release(),
        };
    }

    pub fn retain(self: @This()) @This() {
        self.addRef();
        return self;
    }

    pub fn has(self: @This(), key: anytype) bool {
        return switch (self) {
            .array => |arr| arr.has(key),
            .object => |obj| obj.hasProperty(key) catch false,
        };
    }

    pub fn read(self: @This(), key: anytype) !Value {
        return switch (self) {
            .array => |arr| get: {
                const value = try arr.get(key);
                break :get value.retain();
            },
            .object => |obj| try obj.readProperty(key),
        };
    }

    pub fn iterate(self: @This(), options: Iterator.Options) Iterator {
        return .init(self, options);
    }

    pub fn toValue(self: @This()) Value {
        return switch (self) {
            .array => |arr| arr.toValue(),
            .object => |obj| obj.toValue(),
        };
    }

    pub fn extract(self: *const @This(), allocator: std.mem.Allocator, comptime T: type) !T {
        const st = switch (@typeInfo(T)) {
            .@"struct" => |st| st,
            else => @compileError("Struct type expected, received: " ++ @typeName(T)),
        };
        // create a boolean struct for tracking which fields are missing
        const Found = comptime init: {
            var field_types: [st.field_types.len]type = undefined;
            for (0..st.field_types.len) |i| field_types[i] = bool;
            var field_attrs: [st.field_attrs.len]std.lang.Type.Struct.FieldAttributes = undefined;
            const def_value: bool = false;
            for (0..st.field_attrs.len) |i| field_attrs[i] = .{ .default_value_ptr = &def_value };
            break :init @Struct(.auto, null, st.field_names, &field_types, &field_attrs);
        };
        var found: Found = .{};
        // loop through the properties and set the matching ones
        var iter = self.iterate(.{});
        defer iter.deinit();
        var missing = st.field_names.len;
        var result: T = undefined;
        while (iter.next()) |value| {
            const name = iter.name();
            const unknown = inline for (st.field_names, st.field_types) |field_name, FT| {
                if (N(field_name).match(name)) {
                    const field_result = value.extract(allocator, FT) catch |err| {
                        const msg = failure.acquireMessage(err);
                        defer failure.freeMessage(msg);
                        return failure.report(
                            "unable to obtain value for field '{s}' - {s}",
                            .{ field_name, msg },
                        );
                    };
                    @field(result, field_name) = field_result;
                    @field(found, field_name) = true;
                    missing -= 1;
                    break false;
                }
            } else true;
            if (unknown) {
                const possible_names = comptime php.util.getFieldList(T, "and");
                return failure.report(
                    "encountered unknown field '{s}', expecting {s}",
                    .{ name.slice(), possible_names },
                );
            }
        }
        // use default values when some fields are missing
        if (missing > 0) {
            inline for (st.field_names, st.field_attrs, st.field_types) |field_name, attr, FT| {
                if (!@field(found, field_name)) {
                    if (attr.default_value_ptr) |opaque_ptr| {
                        const field_value_ptr: *const FT = @ptrCast(@alignCast(opaque_ptr));
                        @field(result, field_name) = field_value_ptr.*;
                        @field(found, field_name) = true;
                        missing -= 1;
                    }
                }
            }
            if (missing > 0) {
                // get names of missing fields then report their absence
                var arena: std.heap.ArenaAllocator = .init(php_al);
                defer arena.deinit();
                const arena_al = arena.allocator();
                var list: std.ArrayList([]const u8) = .empty;
                inline for (st.field_names, st.field_attrs) |field_name, attr| {
                    if (attr.default_value_ptr == null) {
                        if (!@field(found, field_name)) {
                            const name = try arena_al.print("'{s}'", .{field_name});
                            try list.append(arena_al, name);
                        }
                    }
                }
                const items = list.items;
                return failure.report("{s} {s}", .{
                    switch (items.len) {
                        0 => unreachable,
                        1 => items[0],
                        2 => try std.mem.join(arena_al, " and ", items),
                        else => try std.mem.join(arena_al, ", and ", &.{
                            try std.mem.join(arena_al, ", ", items[0 .. items.len - 1]),
                            items[items.len - 1],
                        }),
                    },
                    switch (items.len) {
                        1 => "is a required field",
                        else => "are required fields",
                    },
                });
            }
        }
        return result;
    }

    array: *Array,
    object: *Object,
};
