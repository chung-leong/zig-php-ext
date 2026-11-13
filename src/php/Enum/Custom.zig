const std = @import("std");
const builtin = @import("builtin");

const php = @import("../root.zig");
const Array = php.Array;
const c = php.c;
const Class = php.Class;
const Constant = php.Constant;
const Enum = php.Enum;
const failure = php.failure;
const Function = php.Function;
const Object = php.Object;
const pi = php.imports;
const Singleton = php.Singleton;
const String = php.String;
const Value = php.Value;
const argCount = php.util.argCount;

pub fn _(comptime T: type) type {
    comptime try php.util.api.Validator(T, .@"enum", .{}).check();
    return struct {
        pub fn @"enum"(self: *const @This()) *Enum {
            return @constCast(&self.enum_instance);
        }

        pub fn name(self: *const @This()) *String {
            return self.enum_instance.class().name();
        }

        pub fn class(self: *const @This()) *Class {
            return self.enum_instance.class();
        }

        pub fn get() *@This() {
            if (!status.registered) {
                if (builtin.mode == .debug) std.debug.print("Enum is not registered: {}\n", .{T});
                unreachable;
            }
            return instance;
        }

        pub fn isRegistered() bool {
            return status.registered;
        }

        pub fn getValueOf(obj: *Object) !T {
            if (!isRegistered()) return error.EnumNotRegistered;
            if (!obj.isInstanceOf(instance.class())) return error.EnumTypeMismatch;
            const props: [*]Value = @ptrCast(&obj.impl.properties_table[0]);
            const int = props[1].integer();
            return std.enums.fromInt(T, int) orelse error.InvalidEnumValue;
        }

        pub fn register(comptime full_name: []const u8) !*@This() {
            if (status.registered) return instance;
            status.registered = true;
            const enum_instance: *Enum = try .register(full_name, .integer);
            const cls = enum_instance.class();
            // use our own get_method when there're user-defined static methods
            if (@typeInfo(@TypeOf(static_method_set)).@"struct".field_names.len > 0) {
                cls.impl.get_static_method = @ptrCast(&getStaticMethod);
            }
            // add the cases
            const en = @typeInfo(T).@"enum";
            inline for (en.field_names, en.field_values) |field_name, field_value| {
                enum_instance.addCase(.static(field_name), .fromIntegerAny(field_value));
            }
            // add aliases (i.e. public decls that refer to actual enum items)
            inline for (en.decl_names) |decl_name| {
                if (@TypeOf(@field(T, decl_name)) == T and comptime !std.mem.startsWith(u8, "export ", decl_name)) {
                    const decl_value = @field(T, decl_name);
                    const field_index = inline for (en.field_values, 0..) |field_value, i| {
                        if (@backingInt(decl_value) == field_value) break i;
                    };
                    const field_name = en.field_names[field_index];
                    const ast_ref: *Constant.AstRef = .createClassConstFetch(cls.name(), .static(field_name));
                    // class constant registration never fails actually--returning error union only for consistency
                    _ = try Class.Constant.register(decl_name, ast_ref.toValue(), cls);
                }
            }
            const self: *@This() = @ptrCast(enum_instance);
            instance = self;
            return self;
        }

        pub fn registerExports(self: *@This(), comptime parent_name: []const u8) !void {
            if (status.exports_registered) return;
            status.exports_registered = true;
            const class_names = comptime std.meta.fieldNames(@TypeOf(classes));
            var class_instances: php.util.symbol.InstanceTuple(classes) = undefined;
            inline for (class_names, 0..) |class_name, i| {
                const full_class_name = parent_name ++ "\\" ++ class_name;
                class_instances[i] = try .register(full_class_name, null);
                // add the full class path as a constant
                _ = try Class.Constant.register(class_name, .fromString(.static(full_class_name)), self.class());
            }
            const enum_names = comptime std.meta.fieldNames(@TypeOf(enums));
            var enum_instances: php.util.symbol.InstanceTuple(enums) = undefined;
            inline for (enum_names, 0..) |enum_name, i| {
                const full_enum_name = parent_name ++ "\\" ++ enum_name;
                enum_instances[i] = try .register(full_enum_name);
                _ = try Class.Constant.register(enum_name, .fromString(.static(full_enum_name)), self.class());
            }
            inline for (class_instances, class_names) |custom_cls, class_name| {
                try custom_cls.registerExports(parent_name ++ "\\" ++ class_name);
            }
            inline for (enum_instances, enum_names) |custom_enum, enum_name| {
                try custom_enum.registerExports(parent_name ++ "\\" ++ enum_name);
            }
            const const_names = comptime std.meta.fieldNames(@TypeOf(constants));
            const const_types = comptime std.meta.fieldTypes(@TypeOf(constants));
            inline for (const_names, const_types) |const_name, CT| {
                // unlike global constants, it's possible to create persistent non-scalar class
                // constants using AST literals
                const value = @field(constants, const_name);
                const constant_value: Value = switch (comptime php.util.isScalarType(CT)) {
                    true => .createFromAny(value, .{}),
                    false => Constant.AstRef.createLiteral(CT, value).toValue(),
                };
                _ = try Class.Constant.register(const_name, constant_value, self.class());
            }
        }

        pub fn injectCustomEnumHandlers(self: *@This()) !void {
            if (status.handlers_injected) return;
            status.handlers_injected = true;
            // use our own get_method when there're user-defined methods
            if (@typeInfo(@TypeOf(instance_methods)).@"struct".field_names.len > 0) {
                const enum_cls = self.@"enum"().class();
                const ht = pi.zend_separate_class_constants_table(@ptrCast(enum_cls));
                var iter = @as(*Array, @ptrCast(ht)).iterate(.{});
                var handlers_set = false;
                while (iter.next()) |constant_value| {
                    const constant: *Class.Constant = @ptrCast(@alignCast(constant_value.pointer()));
                    const const_value = constant.value();
                    if (const_value.kind() == .object) {
                        const obj = const_value.object();
                        if (obj.class() == enum_cls) {
                            const handlers: *const Object.Handlers = @ptrCast(obj.impl.handlers);
                            if (handlers != &instance_handlers) {
                                if (!handlers_set) {
                                    instance_handlers = handlers.*;
                                    instance_handlers.get_method = @ptrCast(&getInstanceMethod);
                                    instance_get_method = @ptrCast(handlers.get_method);
                                    handlers_set = true;
                                }
                                obj.impl.handlers = @ptrCast(&instance_handlers);
                            }
                        }
                    }
                }
            }
            const class_names = comptime std.meta.fieldNames(@TypeOf(classes));
            inline for (class_names) |class_name| {
                const CustomClass = @field(classes, class_name);
                try CustomClass.get().injectCustomEnumHandlers();
            }
            const enum_names = comptime std.meta.fieldNames(@TypeOf(enums));
            inline for (enum_names) |enum_name| {
                const CustomEnum = @field(enums, enum_name);
                try CustomEnum.get().injectCustomEnumHandlers();
            }
        }

        pub fn initStatic() !void {
            if (Static != void) try Singleton(Static).init();
        }

        pub fn deinitStatic() void {
            if (Static != void) Singleton(Static).deinit();
        }

        fn getStaticMethod(self: *@This(), method_name: *String) callconv(.c) ?*const Function {
            return self.tryGetStaticMethod(method_name) catch |err| {
                if (!failure.match(err, error.Undefined)) {
                    failure.throw(err);
                }
                // look for the method in the class's function table
                const func_table: *Array = @ptrCast(&self.class().impl.function_table);
                const func_value = func_table.get(method_name) catch return null;
                return @ptrCast(@alignCast(func_value.pointer()));
            };
        }

        fn tryGetStaticMethod(self: *@This(), method_name: *String) !*const Function {
            const lc_name = method_name.duplicateLowerCase();
            defer lc_name.release();
            if (static_method_set.find(lc_name)) |func| return func;
            if (!@hasDecl(T, "getStaticMethod")) return error.Undefined;
            return T.getStaticMethod(self.custom(), lc_name);
        }

        fn getInstanceMethod(obj_ptr: **Object, fn_name: *String, key: *Value) callconv(.c) ?*const Function {
            return tryGetInstanceMethod(obj_ptr, fn_name, key) catch |err| {
                // throw the error unless it's `Undefined`
                if (!failure.match(err, error.Undefined)) {
                    failure.throw(err);
                    return null;
                }
                return instance_get_method(obj_ptr, fn_name, key);
            };
        }

        fn tryGetInstanceMethod(obj_ptr: **Object, fn_name: *String, key: *Value) !*const Function {
            const self: *@This() = @ptrCast(obj_ptr.*);
            return instance_method_set.find(key.string()) orelse switch (@hasDecl(T, "getMethod")) {
                true => switch (comptime argCount(@TypeOf(T.getMethod))) {
                    2 => T.getMethod(self.custom(), key.string()),
                    3 => T.getMethod(self.custom(), fn_name, key.string()),
                    else => unreachable,
                },
                false => error.Undefined,
            };
        }

        pub const custom_type: php.util.api.custom.Type = .@"enum";
        pub const Static = php.util.api.FindStatic(T);

        const static_methods = php.util.symbol.MethodExporter(T, .static).get();
        const instance_methods = php.util.symbol.MethodExporter(T, .instance).get();
        const constants = php.util.symbol.ConstantExporter(T).get();
        const enums = php.util.symbol.EnumExporter(T).get();
        const classes = php.util.symbol.ClassExporter(T).get();

        const static_method_set = init: {
            const method_names = std.meta.fieldNames(@TypeOf(static_methods));
            var result: Object.MethodSet(method_names) = undefined;
            for (method_names) |method_name| {
                const method = @field(static_methods, method_name);
                @field(result.entries, method_name) = .init(.static(method_name), method, .{
                    .self_source = .{ .singleton = Static },
                    .is_static = true,
                });
            }
            break :init result;
        };
        const instance_method_set = init: {
            const method_names = std.meta.fieldNames(@TypeOf(instance_methods));
            var result: Object.MethodSet(method_names) = undefined;
            for (method_names) |method_name| {
                const method = @field(instance_methods, method_name);
                @field(result.entries, method_name) = .init(.static(method_name), method, .{
                    .self_source = .{ .this_object = T },
                });
            }
            break :init result;
        };

        var status: packed struct {
            registered: bool = false,
            exports_registered: bool = false,
            handlers_injected: bool = false,
        } = .{};
        var instance: *@This() = undefined;
        var instance_get_method: *const fn (**Object, *String, *Value) callconv(.c) ?*const Function = undefined;
        var instance_handlers: Object.Handlers = undefined;

        enum_instance: Enum,
    };
}
