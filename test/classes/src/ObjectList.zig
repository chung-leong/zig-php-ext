const std = @import("std");

const php = @import("php/root.zig");

pub fn @"call print"(self: *@This(), _: struct {}) !void {
    for (self.list) |animal| {
        php.print("{s} ({})\n", .{ animal.name, animal.type });
    }
}

pub fn init(args: struct {
    list: []const Animal = &.{},
}) !@This() {
    return .{ .list = php.util.retainAny(args.list) };
}

pub fn deinit(self: *@This()) void {
    php.util.freeAny(self.list);
}

const Animal = struct {
    name: []const u8,
    type: enum { pet, wild },
};

list: []const Animal,
ptr: ?[*:0]u8 = null,
