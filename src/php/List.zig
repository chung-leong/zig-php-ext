const std = @import("std");

pub const Iterator = @import("List/Iterator.zig");
const php = @import("root.zig");
const Array = php.Array;
const c = php.c;
const failure = php.failure;
const Object = php.Object;
const php_al = php.allocator;
const String = php.String;
const Value = php.Value;

pub const _ = union(enum) {
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

    pub fn has(self: @This(), index: usize) bool {
        const long: php.Long = @intCast(index);
        return switch (self) {
            .array => |arr| try arr.has(long),
            .object => |obj| try obj.hasDimension(.fromInteger(long)),
        };
    }

    pub fn read(self: @This(), index: usize) !Value {
        const long: php.Long = @intCast(index);
        return switch (self) {
            .array => |arr| get: {
                const value = try arr.get(long);
                break :get value.retain();
            },
            .object => |obj| try obj.readDimension(long),
        };
    }

    pub fn getLength(self: @This()) !usize {
        return switch (self) {
            .array => |arr| arr.length(),
            .object => |obj| obj.countElements() catch {
                return failure.report(
                    "object is unable to provide an element count",
                    .{},
                );
            },
        };
    }

    pub fn iterate(self: @This()) Iterator {
        return .init(self);
    }

    pub fn toValue(self: @This()) Value {
        return switch (self) {
            .array => |arr| arr.toValue(),
            .object => |obj| obj.toValue(),
        };
    }

    pub fn extract(self: *const @This(), allocator: std.mem.Allocator, comptime T: type) !T {
        switch (@typeInfo(T)) {
            .array => |ar| {
                const len = try self.getLength();
                var result: T = undefined;
                if (len != ar.len) {
                    return failure.report(
                        "expecting {d} items, received a list with {d}",
                        .{ ar.len, len },
                    );
                }
                try self.extractInto(allocator, result[0..], ar.child);
                return result;
            },
            .vector => |ve| {
                const array = try self.extract(allocator, [ve.len]ve.child);
                var result: T = undefined;
                inline for (array, 0..) |value, i| result[i] = value;
                return result;
            },
            .pointer => |pt| switch (pt.size) {
                .slice => {
                    const len = try self.getLength();
                    const result = try allocator.alloc(pt.child, len);
                    try self.extractInto(allocator, result, pt.child);
                    return result;
                },
                else => @compileError("Slice pointer type expected, received: " ++ @typeName(T)),
            },
            else => @compileError("Array or slice pointer type expected, received: " ++ @typeName(T)),
        }
    }

    fn extractInto(self: *const @This(), allocator: std.mem.Allocator, slice: anytype, comptime FT: type) !void {
        for (slice, 0..) |*ptr, index| {
            const value = self.extractElement(allocator, index, FT) catch |err| {
                return failure.report(
                    "unable to obtain value for item {d}: {s}",
                    .{ index, failure.acquireMessage(err) },
                );
            };
            ptr.* = value;
        }
    }

    fn extractElement(self: *const @This(), allocator: std.mem.Allocator, index: usize, comptime FT: type) !FT {
        const value = try self.read(index);
        defer value.release();
        return try value.extract(allocator, FT);
    }

    array: *Array,
    object: *Object,
};
