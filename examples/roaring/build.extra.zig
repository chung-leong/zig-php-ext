const std = @import("std");

pub fn getImports(b: *std.Build, args: anytype) []const std.Build.Module.Import {
    const zroaring_dep = b.dependency("zroaring", .{
        .target = args.target,
        .optimize = args.optimize,
    });
    return &.{
        .{ .name = "zroaring", .module = zroaring_dep.module("zroaring") },
    };
}
