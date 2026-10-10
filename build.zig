const std = @import("std");

pub fn build(b: *std.Build) !void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const php_include = b.option([]const u8, "php-include", "Directory containing PHP header files") orelse "php-devel";
    const php_extension = b.option([]const u8, "php-extension", "Directory where the extension will be saved") orelse "extensions";
    const php_debug = b.option(bool, "php-debug", "Whether PHP executable has debug enabled") orelse false;
    const php_ts = b.option(bool, "php-ts", "Whether PHP executable was compiled with thread-safety enabled") orelse false;

    const translate_c = b.addTranslateC(.{
        .root_source_file = b.path("src/include/c.h"),
        .target = target,
        .optimize = optimize,
    });
    translate_c.defineCMacro("ZEND_COMPILE_DL_EXT", null);
    translate_c.defineCMacro("ZEND_DEBUG", if (php_debug) "1" else "0");
    if (php_ts) translate_c.defineCMacro("ZTS", null);

    const mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .single_threaded = false,
        .link_libc = true,
        .imports = &.{
            .{ .name = "c", .module = translate_c.createModule() },
        },
    });
    mod.stack_check = false;
    if (target.result.os.tag == .windows) {
        mod.linkSystemLibrary("dbghelp", .{});
    }

    var app = try std.json.parseFromSliceLeaky(struct {
        name: [:0]const u8,
        version: [:0]const u8,
    }, b.allocator, @embedFile("composer.json"), .{ .ignore_unknown_fields = true });
    if (std.mem.indexOfScalar(u8, app.name, '/')) |index| {
        app.name = app.name[index + 1 ..];
    }

    const lib = b.addLibrary(.{
        .linkage = .dynamic,
        .name = try std.fmt.allocPrint(b.allocator, "php_{s}", .{app.name}),
        .root_module = mod,
        .version = try std.SemanticVersion.parse(app.version),
        .use_llvm = true,
    });
    var c_flags: std.ArrayList([]const u8) = .empty;
    try c_flags.append(b.allocator, "-DZEND_COMPILE_DL_EXT");
    try c_flags.append(b.allocator, if (php_debug) "-DZEND_DEBUG=1" else "-DZEND_DEBUG=0");
    if (php_ts) try c_flags.append(b.allocator, "-DZTS");
    mod.addCSourceFile(.{ .file = b.path("src/main.c"), .flags = c_flags.items });
    if (target.result.os.tag.isDarwin()) {
        // allow symbols from php executable to be undefined
        lib.linker_allow_shlib_undefined = true;
    }

    inline for (.{ translate_c, mod }) |c| {
        const os_specific = if (target.result.os.tag == .linux)
            "src/include/linux"
        else if (target.result.os.tag.isDarwin())
            "src/include/darwin"
        else if (target.result.os.tag == .windows)
            "src/include/win32"
        else
            unreachable;
        c.addIncludePath(b.path(os_specific));
        c.addIncludePath(.{ .cwd_relative = php_include });
        c.addIncludePath(.{ .cwd_relative = try std.fs.path.join(b.allocator, &.{ php_include, "main" }) });
        c.addIncludePath(.{ .cwd_relative = try std.fs.path.join(b.allocator, &.{ php_include, "TSRM" }) });
        c.addIncludePath(.{ .cwd_relative = try std.fs.path.join(b.allocator, &.{ php_include, "Zend" }) });
    }

    const options = b.addOptions();
    options.addOption([:0]const u8, "app_name", app.name);
    options.addOption([:0]const u8, "app_version", app.version);
    lib.root_module.addOptions("options", options);

    const wf = b.addUpdateSourceFiles();
    const ext = if (target.result.os.tag == .linux)
        "so"
    else if (target.result.os.tag.isDarwin())
        "dylib"
    else if (target.result.os.tag == .windows)
        "dll"
    else
        unreachable;
    const filename = try std.fmt.allocPrint(b.allocator, "php_{s}.{s}", .{ app.name, ext });
    wf.addCopyFileToSource(lib.getEmittedBin(), try std.fs.path.join(b.allocator, &.{ php_extension, filename }));
    if (target.result.os.tag == .windows and optimize == .debug) {
        const pdb_filename = try std.fmt.allocPrint(b.allocator, "php_{s}.pdb", .{app.name});
        wf.addCopyFileToSource(lib.getEmittedPdb(), try std.fs.path.join(b.allocator, &.{ php_extension, pdb_filename }));
    }
    wf.step.dependOn(&lib.step);
    b.getInstallStep().dependOn(&wf.step);
    b.installArtifact(lib);
}
