const std = @import("std");

const php = @import("php/root.zig");

pub fn @"call get_array"(_: *@This(), allocator: std.mem.Allocator, args: struct {
    len: usize,
}) ![]i32 {
    const items = try allocator.alloc(i32, args.len);
    for (0..args.len) |i| items[i] = @intCast((i + 1) * 10);
    return items;
}
