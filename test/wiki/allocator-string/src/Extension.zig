const std = @import("std");

const php = @import("php/root.zig");

pub fn @"call get_string"(_: *@This(), allocator: std.mem.Allocator, args: struct {
    name: []const u8,
}) ![]const u8 {
    const slice = try allocator.print("Hello, {s}!", .{args.name});
    php.print("address of allocated memory = 0x{x}\n", .{
        @intFromPtr(slice.ptr),
    });
    return slice;
}

pub fn @"call show_address"(_: *@This(), args: struct {
    string: *php.String,
}) void {
    php.print("address of string contents = 0x{x}\n", .{
        @intFromPtr(args.string.slice().ptr),
    });
}
