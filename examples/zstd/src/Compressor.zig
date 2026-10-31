const std = @import("std");

const zstd = @import("zstd");

const php = @import("php/root.zig");

pub fn init(args: struct {
    options: Options = .{},
}) @This() {
    return .{
        .compressor = .initWithOptions(php.allocator, .{
            .level = args.options.level,
            .strategy = args.options.strategy,
            .checksum = args.options.checksum,
        }),
    };
}

pub fn deinit(self: *@This()) void {
    self.compressor.deinit();
}

pub fn @"call compress"(self: *@This(), allocator: std.mem.Allocator, args: struct {
    chunk: []const u8,
    last: bool,
}) ![]const u8 {
    var compressed: []u8 = &.{};
    var remaining: []const u8 = args.chunk;
    while (true) {
        const result = try self.compressor.compressStream(&self.buffer, remaining, if (args.last) .end else .cont);
        const len = compressed.len;
        compressed = try allocator.realloc(compressed, len + result.outProduced);
        @memcpy(compressed[len..], self.buffer[0..result.outProduced]);
        remaining = remaining[result.inConsumed..];
        if (remaining.len == 0) break;
    }
    return compressed;
}

const Options = struct {
    level: i32 = 3,
    strategy: zstd.Strategy = .fast,
    checksum: bool = false,
};

compressor: zstd.StreamingCompressor,
buffer: [128 * 1024]u8 = undefined,
