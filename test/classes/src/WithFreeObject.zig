const php = @import("php/root.zig");

pub fn freeObject(_: *@This()) !void {
    php.print("freeObject\n", .{});
}

pub fn destroyObject(_: *@This()) !void {
    php.print("destroyObject\n", .{});
}
