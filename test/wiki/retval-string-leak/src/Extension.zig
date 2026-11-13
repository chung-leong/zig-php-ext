const php = @import("php/root.zig");

pub fn @"call get_string"(_: *@This(), args: struct {
    name: []const u8,
}) ![]const u8 {
    // *** DON'T DO THIS ***
    return php.allocator.print("Hello, {s}!", .{args.name});
}
