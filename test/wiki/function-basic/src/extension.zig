const php = @import("php/root.zig");

pub fn foo(_: *@This()) void {
    php.print("foo\n", .{});
}

pub fn bar(_: *@This()) void {
    php.print("bar\n", .{});
}

pub fn @"call foobar"(_: *@This()) void {
    php.print("foobar\n", .{});
}
