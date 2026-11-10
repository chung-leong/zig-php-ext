const php = @import("php/root.zig");

pub fn @"call hello"(_: *@This(), args: struct {
    name: []const u8,
}) !void {
    php.print("Hello, {s}!\n", .{args.name});
}
