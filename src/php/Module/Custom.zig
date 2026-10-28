const std = @import("std");

const php = @import("../root.zig");
const c = php.c;
const pi = php.imports;
const Allocator = php.Allocator;
const Class = php.Class;
const Constant = php.Constant;
const Enumeration = php.Enumeration;
const errable = php.util.errable;
const failure = php.failure;
const unsupported = failure.unsupported;
const Function = php.Function;
const IniEntry = php.IniEntry;
const Module = php.Module;
const php_al = php.allocator;
const Singleton = php.Singleton;
const String = php.String;
const Value = php.Value;
const Dependency = php.Module.Dependency;
const ModuleValidator = php.util.api.ModuleValidator;
const FunctionEntry = @import("Custom/FunctionEntry.zig");
const IniEntryDef = @import("Custom/IniEntryDef.zig");

pub fn @"fn"(comptime T: type, comptime options: struct {
    name: [:0]const u8,
    version: [:0]const u8,
    dependency: ?[]const Dependency = null,
}) type {
    comptime ModuleValidator(T).check();
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
            try registerClasses();
            try registerEnumerations();
            try registerConstants(true);
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
            try registerConstants(false);
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
            const getter_names = comptime std.meta.fieldNames(@TypeOf(getters));
            const setter_names = comptime std.meta.fieldNames(@TypeOf(setters));
            inline for (getter_names, 0..) |getter_name, index| {
                const getter = @field(getters, getter_name);
                const setter, const kind: IniEntry.Kind = comptime for (setter_names) |setter_name| {
                    if (std.mem.startsWith(u8, setter_name, getter_name)) {
                        if (setter_name.len == getter_name.len) {
                            break .{ @field(setters, setter_name), .all };
                        } else if (setter_name[getter_name.len] == ' ') {
                            const suffix = setter_name[getter_name.len + 1 ..];
                            const kind: IniEntry.Kind = for (std.meta.fieldNames(IniEntry.Kind)) |kind_name| {
                                if (std.mem.eql(u8, suffix, "(" ++ kind_name ++ ")")) {
                                    break @field(IniEntry.Kind, kind_name);
                                }
                            } else @compileError("Not a valid ini field suffix: " ++ suffix);
                            break .{ @field(setters, setter_name), kind };
                        }
                    }
                } else @compileError("Missing setter: " ++ getter_name);
                const updater = struct {
                    pub fn onModify(_: *IniEntry, text: *String) !void {
                        const container = Singleton(T).get();
                        const Arg = php.util.ArgType(@TypeOf(setter), 1);
                        const new_value = try fromIniString(Arg, text);
                        return setter(container, new_value);
                    }
                };
                const ini_name = options.name ++ "." ++ getter_name;
                const default_value = try errable(getter(self));
                const default_value_str = try toIniString(allocator, default_value);
                ini_entries[index] = .init(ini_name, kind, default_value_str, updater.onModify);
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

        fn toIniString(allocator: std.mem.Allocator, arg: anytype) ![:0]const u8 {
            const Arg = @TypeOf(arg);
            return switch (@typeInfo(Arg)) {
                .bool => if (arg) "On" else "Off",
                .int, .float => try std.fmt.allocPrintSentinel(allocator, "{d}", 0, .{arg}),
                .pointer => |pt| switch (pt.child) {
                    u8 => if (pt.sentinel() == 0)
                        arg
                    else
                        try std.fmt.allocPrintSentinel(allocator, "{s}", 0, .{arg}),
                    String => arg.slice(),
                    else => unsupported(Arg),
                },
                else => get: {
                    var value: Value = .fromAny(arg).cast(.string);
                    const slice = value.string().slice();
                    break :get slice.ptr;
                },
            };
        }

        fn fromIniString(comptime Arg: type, str: *String) !Arg {
            return switch (@typeInfo(Arg)) {
                .bool => pi.zend_ini_parse_bool(@ptrCast(str)),
                .int => pi.zend_atol(@ptrCast(str)),
                .float => pi.zend_strtod(@ptrCast(str)),
                .pointer => |pt| switch (pt.child) {
                    u8 => str.slice(),
                    String => str.retain(),
                    else => unsupported(Arg),
                },
                else => get: {
                    const value: Value = .fromString(str);
                    break :get value.extract(php_al, Arg);
                },
            };
        }

        fn registerClasses() !void {
            const st = @typeInfo(@TypeOf(classes)).@"struct";
            inline for (st.field_names) |class_name| {
                const CustomClass = @field(classes, class_name);
                const cls: *CustomClass = .create(class_name, null);
                try cls.register();
                try cls.registerChildren(class_name);
            }
        }

        fn registerEnumerations() !void {
            const st = @typeInfo(@TypeOf(enums)).@"struct";
            inline for (st.field_names) |enum_name| {
                const ET = @field(enums, enum_name);
                const CustomEnum = Enumeration.Custom(ET);
                const enumeration: *CustomEnum = .create(enum_name);
                try enumeration.register();
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

        fn registerConstants(persistent: bool) !void {
            const st = @typeInfo(@TypeOf(constants)).@"struct";
            const arr = php.constants();
            inline for (st.field_names, st.field_types) |field_name, FT| {
                const is_literal = switch (@typeInfo(FT)) {
                    .bool, .comptime_int, .int, .comptime_float, .float => true,
                    .pointer => |pt| switch (pt.size) {
                        .one => switch (@typeInfo(pt.child)) {
                            .array => |ar| ar.child == u8,
                            else => false,
                        },
                        .slice => pt.child == u8,
                        else => false,
                    },
                    else => false,
                };
                if (persistent == is_literal) {
                    const value = @field(constants, field_name);
                    const constant: *Constant = .create(field_name, value);
                    try constant.register(arr);
                }
            }
        }

        const getters = php.util.symbol.GetterExporter(T, .instance).get();
        const setters = php.util.symbol.SetterExporter(T, .instance).get();
        const functions = php.util.symbol.MethodExporter(T, .instance).get();
        const constants = php.util.symbol.ConstantExporter(T).get();
        const enums = php.util.symbol.EnumExporter(T).get();
        const classes = php.util.symbol.ClassExporter(T).get();

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
        // ini entries need to be var because their values are determined at runtime
        var ini_entries: VT: {
            const names = std.meta.fieldNames(@TypeOf(getters));
            const count = if (names.len > 0) names.len + 1 else 0;
            break :VT [count]IniEntryDef;
        } = undefined;
        var ini_default_value: T = undefined;

        entry: Module align(@max(@alignOf(Module), @alignOf(T))),
    };
}
