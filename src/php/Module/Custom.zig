const std = @import("std");

const php = @import("../root.zig");
const c = php.c;
const pi = php.imports;
const Allocator = php.Allocator;
const Class = php.Class;
const Constant = php.Constant;
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
                                .type = @backingInt(dep.type),
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
            const self = CustomSingleton.get();
            try registerIniEntries(self, module_no);
            try registerConstants();
            if (!@hasDecl(T, "onModuleStartup")) return;
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
                unregisterConstants();
                unregisterIniEntries(module_no);
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

        fn registerIniEntries(self: *T, module_no: c_int) !void {
            if (ini_entries.len == 0) return;
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

        fn registerConstants() !void {
            for (&constants) |*ptr| try ptr.register();
        }

        fn unregisterConstants() void {
            for (&constants) |*ptr| ptr.unregister();
        }

        fn isCustomClass(comptime Decl: type) bool {
            return switch (@typeInfo(Decl)) {
                .@"struct" => @hasField(Decl, "class") and @FieldType(Decl, "class") == Class,
                else => false,
            };
        }

        const CustomSingleton = Singleton(T);

        const getter_names = php.util.getterNames(T, .instance);
        const setter_names = php.util.setterNames(T, .instance);
        const method_names = php.util.methodNames(T, .instance);
        const export_names = php.util.exportNames(T);
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
        const constants = init: {
            // get count first
            var count: usize = 0;
            for (export_names) |export_name| {
                const prefix = php.util.exportPrefix();
                const decl = @field(T, prefix ++ export_name);
                switch (@typeInfo(@TypeOf(decl))) {
                    .type => if (!isCustomClass(decl)) {
                        const len = get: {
                            switch (@typeInfo(decl)) {
                                .@"struct" => |st| if (st.backing_integer != null) {
                                    var bool_count: usize = 0;
                                    for (st.field_types) |FT| {
                                        if (FT == bool) bool_count += 1;
                                    }
                                    break :get bool_count;
                                },
                                .@"enum" => |en| break :get en.field_names.len,
                                else => {},
                            }
                            @compileError("Expected a custom class, enum, or packed struct, received: " ++ @typeName(decl));
                        };
                        count += len;
                    },
                    else => {
                        count += 1;
                    },
                }
            }
            var entries: [count]Constant = undefined;
            var index: usize = 0;
            for (export_names) |export_name| {
                const prefix = php.util.exportPrefix();
                const decl = @field(T, prefix ++ export_name);
                switch (@typeInfo(@TypeOf(decl))) {
                    .type => if (!isCustomClass(decl)) {
                        // see if export_name is all-cap, then the rest of the name will be capitalized as well
                        const use_uppercase = for (export_name) |ch| {
                            if (std.ascii.isLower(ch)) break false;
                        } else true;
                        const item_names, const item_values = switch (@typeInfo(decl)) {
                            .@"struct" => |st| get: {
                                var bool_count: usize = 0;
                                for (st.field_types) |FT| {
                                    if (FT == bool) bool_count += 1;
                                }
                                var names: [bool_count][:0]const u8 = undefined;
                                var values: [bool_count]c_long = undefined;
                                var value_index: usize = 0;
                                for (st.field_names, 0..) |field_name, i| {
                                    if (st.field_types[i] == bool) {
                                        names[value_index] = field_name;
                                        values[value_index] = @intCast(1 << @bitOffsetOf(decl, field_name));
                                        value_index += 1;
                                    }
                                }
                                break :get .{ names, values };
                            },
                            .@"enum" => |en| get: {
                                var names: [en.field_values.len][:0]const u8 = undefined;
                                var values: [en.field_values.len]c_long = undefined;
                                for (en.field_names, 0..) |field_name, i| {
                                    names[i] = field_name;
                                    values[i] = en.field_values[i];
                                }
                                break :get .{ names, values };
                            },
                            else => unreachable,
                        };
                        for (item_names, 0..) |item_name, i| {
                            const constant_name = create: {
                                const p_len = export_name.len;
                                var buffer: [p_len + 1 + item_name.len]u8 = undefined;
                                @memcpy(buffer[0..p_len], export_name);
                                buffer[p_len] = '_';
                                for (item_name, 0..) |ch, j| buffer[p_len + 1 + j] = switch (use_uppercase) {
                                    true => std.ascii.toUpper(ch),
                                    false => ch,
                                };
                                break :create buffer;
                            };
                            entries[index] = .fromAny(.static(&constant_name), item_values[i]);
                            index += 1;
                        }
                    },
                    else => {
                        entries[index] = .fromAny(.static(export_name), decl);
                        index += 1;
                    },
                }
            }
            break :init entries;
        };
        //  ini entries need to be var because their values are determined at runtime
        const ini_count = if (getter_names.len > 0) getter_names.len + 1 else 0;
        var ini_entries: [ini_count]IniEntryDef = undefined;

        entry: Module,
    };
}
