const std = @import("std");

pub const Iterator = @import("List/Iterator.zig");
const php = @import("root.zig");
const Array = php.Array;
const c = php.c;
const Object = php.Object;
const php_al = php.allocator;
const String = php.String;
const Value = php.Value;

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

    pub fn has(self: @This(), index: usize) bool {
        const long: c.zend_long = @intCast(index);
        return switch (self) {
            .array => |arr| try arr.has(long),
            .object => |obj| try obj.hasDimension(.fromInteger(long)),
        };
    }

    pub fn read(self: @This(), index: usize) !Value {
        const long: c.zend_long = @intCast(index);
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
            .object => |obj| try obj.countElements(),
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
                var result: T = undefined;
                for (0..ar.len) |i| {
                    const value = try self.read(i);
                    defer value.release();
                    result[i] = try value.extract(allocator, ar.child);
                }
                return result;
            },
            .vector => |ve| {
                var result: T = undefined;
                inline for (0..ve.len) |i| {
                    const value = try self.read(i);
                    defer value.release();
                    result[i] = try value.extract(allocator, ve.child);
                }
                return result;
            },
            .pointer => |pt| switch (pt.size) {
                .slice => {
                    const len = try self.getLength();
                    const result = try allocator.alloc(pt.child, len);
                    for (0..len) |i| {
                        const value = try self.read(i);
                        defer value.release();
                        result[i] = try value.extract(allocator, pt.child);
                    }
                    return result;
                },
                else => @compileError("Slice pointer type expected, received: " ++ @typeName(T)),
            },
            else => @compileError("Array or slice pointer type expected, received: " ++ @typeName(T)),
        }
    }

    array: *Array,
    object: *Object,
};
