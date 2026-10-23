const std = @import("std");
const CityHash64 = std.hash.cityhash.CityHash64;

const php = @import("php/root.zig");

pub fn @"call city_hash"(_: *@This(), args: struct {
    data: []const u8,
}) *php.String {
    const hash = CityHash64.hash(args.data);
    return .allocPrint("{x}", .{hash});
}
