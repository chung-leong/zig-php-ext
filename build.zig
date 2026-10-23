const std = @import("std");

const extra = @import("build.extra.zig");

pub fn build(b: *std.Build) !void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    // standard options
    const php_include = b.option([]const u8, "php-include", "Directory containing PHP header files") orelse "php-devel";
    const php_extension = b.option([]const u8, "php-extension", "Directory where the extension will be saved") orelse "extensions";
    const php_debug = b.option(bool, "php-debug", "Whether PHP executable has debug enabled") orelse false;
    const php_ts = b.option(bool, "php-ts", "Whether PHP executable was compiled with thread-safety enabled") orelse false;

    // extra options from composer.json
    var ext = try std.json.parseFromSliceLeaky(struct {
        name: [:0]const u8,
        version: [:0]const u8,
        zig: ?struct {
            config: ?std.json.Value = null,
        } = null,
    }, b.allocator, @embedFile("composer.json"), .{ .ignore_unknown_fields = true });
    if (std.mem.indexOfScalar(u8, ext.name, '/')) |index| {
        ext.name = ext.name[index + 1 ..];
    }
    const options = b.addOptions();
    options.addOption([:0]const u8, "ext_name", ext.name);
    options.addOption([:0]const u8, "ext_version", ext.version);
    if (ext.zig) |zig| {
        if (zig.config) |config| {
            switch (config) {
                .object => |map| {
                    var iter = map.iterator();
                    while (iter.next()) |entry| {
                        const name = entry.key_ptr.*;
                        const info = switch (entry.value_ptr.*) {
                            .object => |obj| obj,
                            else => |_, tag| {
                                std.debug.print("config entries are expected to be objects, found: {}", .{tag});
                                return error.UnexpectedType;
                            },
                        };
                        const description = init: {
                            const desc_value = info.get("description") orelse info.get("prompt") orelse break :init "[description]";
                            switch (desc_value) {
                                .string => |str| break :init try b.allocator.dupeSentinel(u8, str, 0),
                                else => return error.StringExpected,
                            }
                        };
                        const type_name = init: {
                            const type_value = info.get("type") orelse {
                                // infer the value type from the default value
                                const def_value = info.get("default") orelse return error.MissingDefaultValue;
                                break :init switch (def_value) {
                                    .bool => "bool",
                                    .integer => "i64",
                                    .float => "f64",
                                    .string => "[]const u8",
                                    else => return error.MissingTypeName,
                                };
                            };
                            break :init switch (type_value) {
                                .string => |str| str,
                                else => return error.StringExpected,
                            };
                        };
                        // check types defined in composer.zig first
                        const composer = @import("composer.zig");
                        inline for (comptime std.meta.declarations(composer)) |decl_name| {
                            if (std.mem.eql(u8, type_name, decl_name)) {
                                const T = @field(composer, decl_name);
                                switch (@typeInfo(T)) {
                                    .@"enum" => {
                                        if (b.option(T, name, description)) |value| {
                                            options.addOption(T, name, value);
                                        }
                                    },
                                    .@"struct" => |st| switch (st.layout) {
                                        .@"packed" => {
                                            var value: T = undefined;
                                            inline for (comptime std.meta.fieldNames(T)) |field_name| {
                                                const item_name = try std.fmt.allocPrint(b.allocator, "{s}_{s}", .{ name, field_name });
                                                const item_desc = try std.fmt.allocPrint(b.allocator, "{s}: {s}", .{ description, field_name });
                                                @field(value, field_name) = b.option(bool, item_name, item_desc) orelse false;
                                            }
                                            options.addOption(T, name, value);
                                        },
                                        else => {},
                                    },
                                    else => {},
                                }
                                break;
                            }
                        } else inline for (.{ bool, c_int, c_uint, c_long, c_ulong, usize, isize, i8, i16, i32, i64, u8, u16, u32, u64, f16, f32, f64, []const u8 }) |T| {
                            if (std.mem.eql(u8, type_name, @typeName(T))) {
                                if (b.option(T, name, description)) |value| {
                                    if (T == []const u8) {
                                        // always use strings with sentinel
                                        options.addOption([:0]const u8, name, try b.allocator.dupeSentinel(u8, value, 0));
                                    } else {
                                        options.addOption(T, name, value);
                                    }
                                }
                                break;
                            }
                        } else {
                            std.debug.print("Unknown type: {s}\n", .{type_name});
                            return error.UnknownType;
                        }
                    }
                },
                else => |_, tag| {
                    std.debug.print("'config' is expected to be an object, found: {}", .{tag});
                    return error.UnexpectedType;
                },
            }
        }
    }

    const translate_c = b.addTranslateC(.{
        .root_source_file = b.path("src/include/c.h"),
        .target = target,
        .optimize = optimize,
    });
    translate_c.defineCMacro("ZEND_COMPILE_DL_EXT", null);
    translate_c.defineCMacro("ZEND_DEBUG", if (php_debug) "1" else "0");
    if (php_ts) translate_c.defineCMacro("ZTS", null);

    const std_imports: []const std.Build.Module.Import = &.{
        .{ .name = "c", .module = translate_c.createModule() },
    };
    const extra_imports: []const std.Build.Module.Import = switch (@hasDecl(extra, "getImports")) {
        true => @call(.always_inline, extra.getImports, .{ b, .{
            .target = target,
            .optimize = optimize,
        } }),
        false => &.{},
    };
    const mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .single_threaded = false,
        .link_libc = true,
        .imports = try std.mem.concat(b.allocator, std.Build.Module.Import, &.{
            std_imports,
            extra_imports,
        }),
    });
    mod.stack_check = false;
    if (target.result.os.tag == .windows) {
        mod.linkSystemLibrary("dbghelp", .{});
    }
    mod.addOptions("config", options);

    const so_name = try std.fmt.allocPrint(b.allocator, "php_{s}", .{ext.name});
    for (so_name) |*ptr| {
        if (ptr.* == '-') ptr.* = '_';
    }
    const lib = b.addLibrary(.{
        .linkage = .dynamic,
        .name = so_name,
        .root_module = mod,
        .version = try std.SemanticVersion.parse(ext.version),
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
    const extra_c_files: []const std.Build.Module.CSourceFile = switch (@hasDecl(extra, "getCSourceFiles")) {
        true => @call(.always_inline, extra.getCSourceFiles, .{ b, .{
            .library = lib,
            .module = mod,
            .target = target,
            .optimize = optimize,
        } }),
        false => &.{},
    };
    for (extra_c_files) |file| mod.addCSourceFile(file);
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
    const extra_include_paths: []const std.Build.LazyPath = switch (@hasDecl(extra, "getIncludePaths")) {
        true => @call(.always_inline, extra.getIncludePaths, .{ b, .{
            .library = lib,
            .module = mod,
            .target = target,
            .optimize = optimize,
        } }),
        false => &.{},
    };
    for (extra_include_paths) |path| mod.addIncludePath(path);

    const wf = b.addUpdateSourceFiles();
    const so_ext = if (target.result.os.tag == .linux)
        "so"
    else if (target.result.os.tag.isDarwin())
        "dylib"
    else if (target.result.os.tag == .windows)
        "dll"
    else
        unreachable;
    const filename = try std.fmt.allocPrint(b.allocator, "{s}.{s}", .{ so_name, so_ext });
    wf.addCopyFileToSource(lib.getEmittedBin(), try std.fs.path.join(b.allocator, &.{ php_extension, filename }));
    if (target.result.os.tag == .windows and optimize == .debug) {
        const pdb_filename = try std.fmt.allocPrint(b.allocator, "php_{s}.pdb", .{ext.name});
        wf.addCopyFileToSource(lib.getEmittedPdb(), try std.fs.path.join(b.allocator, &.{ php_extension, pdb_filename }));
    }
    wf.step.dependOn(&lib.step);
    b.getInstallStep().dependOn(&wf.step);
    b.installArtifact(lib);
}
