const php = @import("php/root.zig");

pub fn init(args: struct {
    number: i32,
}) !@This() {
    _ = args;
    php.print("init\n", .{});
    return error.Uncreatable;
}

pub fn deinit(self: *@This()) void {
    _ = self;
    php.print("unreachable\n", .{});
}
