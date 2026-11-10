const php = @import("php/root.zig");

pub fn @"call hello"(_: *@This(), args: struct {
    name: *php.String,
}) !void {
    php.print("Hello, {s}!\n", .{args.name.slice()});
}
