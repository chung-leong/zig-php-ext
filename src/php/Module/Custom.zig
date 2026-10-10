const std = @import("std");

const php = @import("../root.zig");
const c = php.c;
const pi = php.imports;
const Allocator = php.Allocator;
const Function = php.Function;
const failure = php.failure;
const Module = php.Module;
const Singleton = php.Singleton;
const errable = php.util.errable;
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
                                .type = @intFromEnum(dep.type),
                            };
                        }
                        deps[list.len] = .{ .name = null };
                        break :init &deps;
                    } else null,
                    .name = options.name.ptr,
                    .functions = @ptrCast(&function_entries),
                    .module_startup_func = @ptrCast(&onModuleStartup),
                    .module_shutdown_func = @ptrCast(&onModuleShutdown),
                    .request_startup_func = @ptrCast(&onRequestStartup),
                    .request_shutdown_func = @ptrCast(&onRequestShutdown),
                    .info_func = @ptrCast(&onInfoRequest),
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

        fn onModuleStartup(module_type: Module.Type, module_no: c_int) callconv(.c) c.zend_result {
            tryModuleStartup(module_type, module_no) catch |err| {
                failure.show(err);
                return c.FAILURE;
            };
            return c.SUCCESS;
        }

        fn tryModuleStartup(module_type: Module.Type, module_no: c_int) !void {
            try CustomSingleton.init();
            if (!@hasDecl(T, "onModuleStartup")) return;
            const self = CustomSingleton.get();
            // initialize the ini entries after we have create the singleton
            var arena: std.heap.ArenaAllocator = .init(php.allocator);
            defer arena.deinit();
            const allocator = arena.allocator();
            inline for (getter_names, 0..) |getter_name, index| {
                const setter_name = comptime for (setter_names) |name| {
                    if (std.mem.startsWith(u8, name, getter_name)) {
                        if (name.len == getter_name.len or name[getter_name.len] == ' ') {
                            break name;
                        }
                    }
                } else @compileError("Missing setter: " ++ getter_name);
                ini_entries[index] = .init(allocator, self, options.name, getter_name, setter_name);
            }
            if (pi.zend_register_ini_entries(@ptrCast(&ini_entries), module_no) != c.SUCCESS) return error.CannotRegisterIniEntries;
            return T.onModuleStartup(self, module_type, module_no);
        }

        fn onModuleShutdown(module_type: Module.Type, module_no: c_int) callconv(.c) c.zend_result {
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
                CustomSingleton.deinit();
                pi.zend_unregister_ini_entries(module_no);
            }
            if (!@hasDecl(T, "onModuleShutdown")) return;
            const self = CustomSingleton.get();
            return T.onModuleShutdown(self, module_type, module_no);
        }

        fn onRequestStartup(module_type: Module.Type, module_no: c_int) callconv(.c) c.zend_result {
            tryRequestStartup(module_type, module_no) catch |err| {
                failure.show(err);
                return c.FAILURE;
            };
            return c.SUCCESS;
        }

        fn tryRequestStartup(module_type: Module.Type, module_no: c_int) !void {
            Allocator.mode = .per_request;
            if (!@hasDecl(T, "onRequestStartup")) return;
            const self = CustomSingleton.get();
            return T.onRequestStartup(self, module_type, module_no);
        }

        fn onRequestShutdown(module_type: Module.Type, module_no: c_int) callconv(.c) c.zend_result {
            tryRequestShutdown(module_type, module_no) catch |err| {
                failure.show(err);
                return c.FAILURE;
            };
            return c.SUCCESS;
        }

        fn tryRequestShutdown(module_type: Module.Type, module_no: c_int) !void {
            defer CustomSingleton.reset();
            if (!@hasDecl(T, "onRequestShutdown")) return;
            const self = CustomSingleton.get();
            return T.onRequestShutdown(self, module_type, module_no);
        }

        fn onInfoRequest(module: *Module) callconv(.c) void {
            tryInfoRequest(module) catch |err| {
                failure.show(err);
            };
        }

        fn tryInfoRequest(module: *Module) !void {
            Allocator.mode = .per_request;
            if (!@hasDecl(T, "onInfoRequest")) return;
            const self = CustomSingleton.get();
            return T.onInfoRequest(self, module);
        }

        const CustomSingleton = Singleton(T);

        const getter_names = php.util.getterNames(T, .instance);
        const setter_names = php.util.setterNames(T, .instance);
        const method_names = php.util.methodNames(T, .instance);
        const function_entries = init: {
            // create entries for them (extra entry for sentinel)
            var entries: [method_names.len + 1]FunctionEntry = undefined;
            var i: usize = 0;
            const prefix = php.util.methodPrefix(.instance);
            for (method_names) |method_name| {
                entries[i] = .init(T, method_name, @field(T, prefix ++ method_name));
                i += 1;
            }
            // list is terminated by an empty entry
            entries[i] = std.mem.zeroes(FunctionEntry);
            break :init entries;
        };
        //  ini entries need to be var because their values are determined at runtime
        var ini_entries: [getter_names.len]IniEntryDef = undefined;

        entry: Module,
    };
}
