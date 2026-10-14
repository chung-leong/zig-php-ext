const std = @import("std");

const php = @import("../root.zig");
const c = php.c;
const pi = php.imports;
const Allocator = php.Allocator;
const Class = php.Class;
const Constant = php.Constant;
const errable = php.util.errable;
const Function = php.Function;
const failure = php.failure;
const Module = php.Module;
const Singleton = php.Singleton;
const String = php.String;
const Dependency = php.Module.Dependency;
const FunctionEntry = @import("Custom/FunctionEntry.zig");
const IniEntryDef = @import("Custom/IniEntryDef.zig");

pub fn @"fn"(comptime T: type, comptime options: struct {
    name: [:0]const u8,
    version: [:0]const u8,
    dependency: ?[]const Dependency = null,
}) type {
    if (@typeInfo(T) != .@"struct") @compileError("Expected struct, received: " ++ @typeName(T));
    return struct {
        pub fn init() @This() {
            return .{
                .entry = .fromZendModuleEntry(.{
                    .size = @sizeOf(@This()),
                    .zend_api = php.api_no,
                    .zend_debug = if (php.debug) 1 else 0,
                    .zts = if (php.use_tsrm) 1 else 0,
                    .ini_entry = null,
                    .deps = if (options.dependency) |list| init: {
                        var deps: [list.len + 1]c.struct__zend_module_dep = undefined;
                        for (list) |dep| {
                            deps = .{
                                .name = dep.name.ptr,
                                .rel = @tagName(dep.rel),
                                .version = dep.version.ptr,
                                .type = @backingInt(dep.type),
                            };
                        }
                        deps[list.len] = .{ .name = null };
                        break :init &deps;
                    } else null,
                    .name = options.name.ptr,
                    .functions = @ptrCast(&function_entries),
                    .module_startup_func = @ptrCast(&moduleStartup),
                    .module_shutdown_func = @ptrCast(&moduleShutdown),
                    .request_startup_func = @ptrCast(&requestStartup),
                    .request_shutdown_func = @ptrCast(&requestShutdown),
                    .info_func = @ptrCast(&infoRequest),
                    .version = options.version.ptr,
                    .build_id = php.build_id,
                }),
            };
        }

        pub fn register(comptime self: *@This()) void {
            const export_ns = struct {
                pub fn getModule() callconv(.c) *c.zend_module_entry {
                    return @ptrCast(&self.entry);
                }
            };
            @export(&export_ns.getModule, .{ .name = "get_module" });
        }

        fn moduleStartup(module_type: Module.Type, module_no: c_int) callconv(.c) c.zend_result {
            tryModuleStartup(module_type, module_no) catch |err| {
                failure.show(err);
                return c.FAILURE;
            };
            return c.SUCCESS;
        }

        fn tryModuleStartup(module_type: Module.Type, module_no: c_int) !void {
            try Singleton(T).init();
            const self = Singleton(T).get();
            // save the default values used by the extension
            ini_default_value = self.*;
            try registerIniEntries(self, module_no);
            try registerConstants();
            try registerClasses();
            if (!@hasDecl(T, "moduleStartup")) return;
            return T.moduleStartup(self, module_type, module_no);
        }

        fn moduleShutdown(module_type: Module.Type, module_no: c_int) callconv(.c) c.zend_result {
            tryModuleShutdown(module_type, module_no) catch |err| {
                failure.show(err);
                return c.FAILURE;
            };
            return c.SUCCESS;
        }

        fn tryModuleShutdown(module_type: Module.Type, module_no: c_int) !void {
            // switch allocation back to persistent mode
            Allocator.mode = .persistent;
            defer {
                Singleton(T).deinit();
                unregisterClasses();
                unregisterConstants();
                unregisterIniEntries(module_no);
            }
            if (!@hasDecl(T, "moduleShutdown")) return;
            const self = Singleton(T).get();
            return T.moduleShutdown(self, module_type, module_no);
        }

        fn requestStartup(module_type: Module.Type, module_no: c_int) callconv(.c) c.zend_result {
            tryRequestStartup(module_type, module_no) catch |err| {
                failure.show(err);
                return c.FAILURE;
            };
            return c.SUCCESS;
        }

        fn tryRequestStartup(module_type: Module.Type, module_no: c_int) !void {
            Allocator.mode = .per_request;
            try initializeClassStatic();
            if (!@hasDecl(T, "requestStartup")) return;
            const self = Singleton(T).get();
            return T.requestStartup(self, module_type, module_no);
        }

        fn requestShutdown(module_type: Module.Type, module_no: c_int) callconv(.c) c.zend_result {
            tryRequestShutdown(module_type, module_no) catch |err| {
                failure.show(err);
                return c.FAILURE;
            };
            return c.SUCCESS;
        }

        fn tryRequestShutdown(module_type: Module.Type, module_no: c_int) !void {
            defer {
                Singleton(T).reset(ini_default_value);
                deinitializeClassStatic();
            }
            if (!@hasDecl(T, "requestShutdown")) return;
            const self = Singleton(T).get();
            return T.requestShutdown(self, module_type, module_no);
        }

        fn infoRequest(module: *Module) callconv(.c) void {
            tryInfoRequest(module) catch |err| {
                failure.show(err);
            };
        }

        fn tryInfoRequest(module: *Module) !void {
            Allocator.mode = .per_request;
            if (!@hasDecl(T, "infoRequest")) return;
            const self = Singleton(T).get();
            return T.infoRequest(self, module);
        }

        fn registerIniEntries(self: *T, module_no: c_int) !void {
            if (ini_entries.len == 0) return;
            // initialize the ini entries after we have create the singleton
            var arena: std.heap.ArenaAllocator = .init(php.allocator);
            defer arena.deinit();
            const allocator = arena.allocator();
            inline for (comptime std.meta.fieldNames(@TypeOf(getters)), 0..) |getter_name, index| {
                const setter_name = comptime for (std.meta.fieldNames(setters)) |name| {
                    if (std.mem.startsWith(u8, name, getter_name)) {
                        if (name.len == getter_name.len or name[getter_name.len] == ' ') {
                            break name;
                        }
                    }
                } else @compileError("Missing setter: " ++ getter_name);
                ini_entries[index] = .init(allocator, self, options.name, getter_name, setter_name);
            }
            // last entry is delimiter
            ini_entries[ini_entries.len - 1] = std.mem.zeroes(IniEntryDef);
            if (pi.zend_register_ini_entries(@ptrCast(&ini_entries), module_no) != c.SUCCESS) {
                return error.CannotRegisterIniEntries;
            }
        }

        fn unregisterIniEntries(module_no: c_int) void {
            if (ini_entries.len == 0) return;
            pi.zend_unregister_ini_entries(module_no);
        }

        fn registerClasses() !void {
            inline for (comptime std.meta.fieldNames(@TypeOf(classes))) |class_name| {
                @field(classes, class_name) = .init(String.static(class_name), null);
                try @field(classes, class_name).register();
            }
        }

        fn unregisterClasses() void {
            inline for (comptime std.meta.fieldNames(@TypeOf(classes))) |class_name| {
                @field(classes, class_name).unregister();
            }
        }

        fn initializeClassStatic() !void {
            inline for (comptime std.meta.fieldNames(@TypeOf(classes))) |class_name| {
                try @field(classes, class_name).initStatic();
            }
        }

        fn deinitializeClassStatic() void {
            inline for (comptime std.meta.fieldNames(@TypeOf(classes))) |class_name| {
                @field(classes, class_name).deinitStatic();
            }
        }

        fn registerConstants() !void {
            for (&constants) |*ptr| try ptr.register();
        }

        fn unregisterConstants() void {
            for (&constants) |*ptr| ptr.unregister();
        }

        const constants = php.util.symbol.ExportedConstants(T).get();
        const getters = php.util.symbol.Extractor(T, .getter, .instance).get();
        const setters = php.util.symbol.Extractor(T, .setter, .instance).get();
        const functions = php.util.symbol.Extractor(T, .method, .instance).get();
        const function_entries = init: {
            // create entries for them (extra entry for sentinel)
            const function_names = std.meta.fieldNames(@TypeOf(functions));
            var entries: [function_names.len + 1]FunctionEntry = undefined;
            var i: usize = 0;
            for (function_names) |function_name| {
                const function = @field(functions, function_name);
                entries[i] = .init(T, function_name, function);
                i += 1;
            }
            // list is terminated by an empty entry
            entries[i] = std.mem.zeroes(FunctionEntry);
            break :init entries;
        };
        // class need to be initialized at runtime since symbols exported by PHP like stdclass
        // aren't known at comptime
        var classes: php.util.symbol.ExportedClasses(T) = undefined;
        // ini entries need to be var because their values are determined at runtime
        var ini_entries: type: {
            const names = std.meta.fieldNames(@TypeOf(getters));
            const count = if (names.len > 0) names.len + 1 else 0;
            break :type [count]IniEntryDef;
        } = undefined;
        var ini_default_value: T = undefined;

        entry: Module align(@max(@alignOf(Module), @alignOf(T))),
    };
}
