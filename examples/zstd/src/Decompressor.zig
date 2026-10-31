const std = @import("std");

const zstd = @import("zstd");

const php = @import("php/root.zig");

pub fn init() @This() {
    return .{
        .decompressor = .init(php.allocator),
    };
}

pub fn deinit(self: *@This()) void {
    self.decompressor.deinit();
}

pub fn @"call decompress"(self: *@This(), allocator: std.mem.Allocator, args: struct {
    chunk: []const u8,
}) ![]const u8 {
    var decompressed: []u8 = &.{};
    var remaining: []const u8 = args.chunk;
    while (true) {
        const result = try self.decompressor.decompressStream(&self.buffer, remaining);
        const len = decompressed.len;
        decompressed = try allocator.realloc(decompressed, len + result.outProduced);
        @memcpy(decompressed[len..], self.buffer[0..result.outProduced]);
        remaining = remaining[result.inConsumed..];
        if (remaining.len == 0) break;
    }
    return decompressed;
}

decompressor: zstd.StreamingDecompressor,
buffer: [128 * 1024]u8 = undefined,
