const std = @import("std");
const CityHash64 = std.hash.cityhash.CityHash64;

const php = @import("php/root.zig");

const Options = struct {
    seed: ?u64 = null,
    uppercase: bool = false,
};

pub fn @"call city_hash"(_: *@This(), args: struct {
    data: []const u8,
    options: Options = .{},
}) *php.String {
    const hash = if (args.options.seed) |seed|
        CityHash64.hashWithSeed(args.data, seed)
    else
        CityHash64.hash(args.data);
    return switch (args.options.uppercase) {
        true => .allocPrint("{X}", .{hash}),
        false => .allocPrint("{x}", .{hash}),
    };
}
