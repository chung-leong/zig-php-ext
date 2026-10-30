const std = @import("std");

pub fn getImports(b: *std.Build, args: anytype) []const std.Build.Module.Import {
    const zstd_dep = b.dependency("zstd", .{
        .target = args.target,
        .optimize = args.optimize,
    });
    return &.{
        .{ .name = "zstd", .module = zstd_dep.module("zstd") },
    };
}

pub fn getCSourceFiles(b: *std.Build, args: anytype) []const std.Build.Module.CSourceFile {
    _ = b;
    _ = args;
    // args contains the following:
    //
    //     library: *std.Build.Step.Compile,
    //     module: *std.Build.Module,
    //     target: std.Build.ResolvedTarget,
    //     optimize: std.builtin.OptimizeMode,
    return &.{};
}

pub fn getIncludePaths(b: *std.Build, args: anytype) []const std.Build.LazyPath {
    _ = b;
    _ = args;
    // args contains the following:
    //
    //     library: *std.Build.Step.Compile,
    //     module: *std.Build.Module,
    //     target: std.Build.ResolvedTarget,
    //     optimize: std.builtin.OptimizeMode,
    return &.{};
}
