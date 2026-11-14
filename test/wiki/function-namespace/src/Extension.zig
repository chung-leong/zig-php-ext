const php = @import("php/root.zig");

pub fn @"call somewhere\\out\\there\\foobar"(_: *@This()) void {
    php.print("foobar\n", .{});
}
