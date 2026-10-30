const std = @import("std");

const zstd = @import("zstd");

const php = @import("php/root.zig");

pub fn @"static call compress"(_: *Static, allocator: std.mem.Allocator, args: struct {
    data: []const u8,
    options: Options = .{},
}) ![]const u8 {
    return try zstd.compressWithOptions(allocator, args.data, .{
        .level = args.options.level,
        .strategy = args.options.strategy,
        .checksum = args.options.checksum,
    });
}

pub fn @"static call decompress"(_: *Static, allocator: std.mem.Allocator, args: struct {
    data: []const u8,
}) ![]const u8 {
    return try zstd.decompress(allocator, args.data);
}

const Static = struct {};
const Options = struct {
    level: i32 = 3,
    strategy: zstd.Strategy = .fast,
    checksum: bool = false,
};
