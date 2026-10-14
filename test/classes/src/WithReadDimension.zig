const std = @import("std");

const php = @import("php/root.zig");
const Object = php.Object;
const getter = Object.getter;
const Value = php.Value;

pub fn @"get len"(self: *@This()) usize {
    return self.items.len;
}

pub fn readDimension(self: *@This(), offset: Value, access: Value.Access) !Value {
    const index: usize = try offset.getUnsigned();
    php.print("(readDimension: {d}) ", .{index});
    if (index >= self.items.len) switch (access) {
        .isset => return .fromNull(),
        else => return error.OutOfBound,
    };
    return .fromFloat(self.items[index]);
}

pub fn writeDimension(self: *@This(), offset: Value, value: Value) !void {
    const index: usize = try offset.getUnsigned();
    php.print("(writeDimension: {d}) ", .{index});
    if (index >= self.items.len) return error.OutOfBound;
    self.items[index] = try value.getFloat();
}

pub fn hasDimension(self: *@This(), offset: Value, _: bool) !bool {
    const index: usize = offset.getUnsigned() catch return false;
    php.print("(hasDimension: {d}) ", .{index});
    if (index >= self.items.len) return false;
    return true;
}

pub fn unsetDimension(self: *@This(), offset: Value) !void {
    const index: usize = try offset.getUnsigned();
    php.print("(unsetDimension: {d}) ", .{index});
    self.items[index] = std.math.nan(f64);
}

items: [8]f64 = .{ 0, 0, 0, 0, 0, 0, 0, 0 },
