const std = @import("std");

const php = @import("php/root.zig");

const NumberIterator = struct {
    pub fn next(self: *@This()) ?i32 {
        if (self.current > self.last) return null;
        defer self.current += 1;
        return self.current;
    }

    current: i32 = 0,
    last: i32,
};

pub fn iterate(_: *@This(), _: struct {}) !NumberIterator {
    php.print("iterate\n", .{});
    return .{ .last = 4 };
}
