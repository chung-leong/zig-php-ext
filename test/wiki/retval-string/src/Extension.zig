const std = @import("std");

const php = @import("php/root.zig");

pub fn @"call get_string"(_: *@This(), allocator: std.mem.Allocator, args: struct {
    name: []const u8,
}) ![]const u8 {
    return allocator.print("Hello, {s}!", .{args.name});
}
