const std = @import("std");

const zstd = @import("zstd");

const php = @import("php/root.zig");

pub const @"export zstd\\Compressor" = php.Class.Custom(@import("Compressor.zig"));
pub const @"export zstd\\Decompressor" = php.Class.Custom(@import("Decompressor.zig"));

pub fn @"call zstd\\compress"(_: *@This(), allocator: std.mem.Allocator, args: struct {
    data: []const u8,
    options: struct {
        level: i32 = 3,
        strategy: zstd.Strategy = .fast,
        checksum: bool = false,
    } = .{},
}) ![]const u8 {
    return try zstd.compressWithOptions(allocator, args.data, .{
        .level = args.options.level,
        .strategy = args.options.strategy,
        .checksum = args.options.checksum,
    });
}

pub fn @"call zstd\\decompress"(_: *@This(), allocator: std.mem.Allocator, args: struct {
    data: []const u8,
}) ![]const u8 {
    return try zstd.decompress(allocator, args.data);
}
