const std = @import("std");
const builtin = @import("builtin");

const php = @import("../root.zig");
const c = php.c;
const deref = php.deref;
const pi = php.imports;
const php_al = php.allocator;
const Array = php.Array;
const Allocator = php.Allocator;
const Class = php.Class;
const Constant = php.Constant;
const Enum = php.Enum;
const errable = php.errable;
const failure = php.failure;
const Function = php.Function;
const Object = php.Object;
const Singleton = php.Singleton;
const String = php.String;
const Value = php.Value;
const ReturnType = php.util.ReturnType;
const ClassValidator = php.util.api.ClassValidator;

pub fn @"fn"(comptime T: type) type {
    comptime ClassValidator(T).check();
    return struct {
        pub fn name(self: *const @This()) *String {
            return self.class_entry.name();
        }

        pub fn class(self: *const @This()) *Class {
            return @ptrCast(@constCast(self));
        }

        pub fn get() *@This() {
            return registered orelse {
                if (builtin.mode == .debug) {
                    std.debug.print("Class is not registered: {}\n", .{T});
                }
                unreachable;
            };
        }

        pub fn custom(_: *@This()) *T {
            return Singleton(T).get();
        }

        pub fn parent(self: *const @This()) *Class {
            return self.class_entry.parent();
        }

        pub fn flags(self: *const @This()) Class.Flags {
            return self.class_entry.flags();
        }

        pub fn isRegistered() bool {
            return registered != null;
        }

        pub fn register(comptime full_name: []const u8, parent_class: ?*Class) !*@This() {
            return registered orelse create: {
                const class_name: *String = .static(full_name);
                const self: *@This() = .create(class_name, parent_class);
                const cg = php.globals("compiler");
                const list: *Array = @ptrCast(cg.class_table);
                const lc_name = self.name().duplicateLowerCase();
                defer lc_name.release();
                if (list.has(lc_name)) return error.NameConflict;
                list.set(lc_name, .fromPointer(&self.class_entry.impl));
                self.addRef();
                registered = self;
                const st = @typeInfo(T).@"struct";
                if (st.layout == .@"packed") {
                    // add bits of bool fields as constants so the user can use the to toggle flags
                    inline for (st.field_names, st.field_types) |field_name, FT| {
                        if (FT == bool) {
                            const constant_value: Value = .fromAny(1 << @bitOffsetOf(T, field_name), .{});
                            _ = try Class.Constant.register(field_name, constant_value, self.class());
                        }
                    }
                }
                break :create self;
            };
        }

        pub fn registerExports(self: *@This(), comptime parent_name: []const u8) !void {
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
                    true => .fromAny(value, .{}),
                    false => Constant.AstRef.createLiteral(CT, value).toValue(),
                };
                _ = try Class.Constant.register(const_name, constant_value, self.class());
            }
        }

        pub fn addRef(self: *@This()) void {
            self.class_entry.impl.refcount += 1;
        }

        pub fn release(self: *@This()) void {
            self.class_entry.impl.refcount -= 1;
            if (self.class_entry.impl.refcount == 0) {
                php_al.destroy(self);
            }
        }

        pub fn initStatic() !void {
            if (Static != void) try Singleton(Static).init();
        }

        pub fn deinitStatic() void {
            if (Static != void) Singleton(Static).deinit();
        }

        pub fn create(class_name: *String, parent_class: ?*Class) *@This() {
            const self = php_al.create(@This()) catch unreachable;
            errdefer php_al.destroy(self);
            // determine what interfaces the class supports based on implementation of certain methods
            const interfaces = init: {
                const has_array_access = @hasDecl(T, "readDimension") or @hasDecl(T, "writeDimension");
                const has_countable = @hasDecl(T, "countDimension");
                const has_traversable = Instance.has_iterator;
                comptime var count: usize = 0;
                if (has_array_access) count += 1;
                if (has_countable) count += 1;
                if (has_traversable) count += 1;
                var interfaces: [count]*const Class = undefined;
                comptime var i: usize = 0;
                if (has_array_access) {
                    interfaces[i] = .interface(.array_access);
                    i += 1;
                }
                if (has_countable) {
                    interfaces[i] = .interface(.countable);
                    i += 1;
                }
                if (has_traversable) {
                    interfaces[i] = .interface(.traversable);
                    i += 1;
                }
                break :init &interfaces;
            };
            const class_flags: Class.Flags = .{
                .linked = true,
                .no_dynamic_properties = true,
                .resolved_interfaces = true,
                .resolved_parent = true,
                .not_serializable = !@hasDecl(T, "serialize"),
                .abstract = std.meta.declarations(T).len == 0,
            };
            const class_pce = parent_class orelse Class.builtin(.standard);
            const zce = &self.class_entry.impl;
            zce.* = .{};
            zce.type = c.ZEND_INTERNAL_CLASS;
            zce.refcount = 1;
            zce.name = @ptrCast(class_name);
            zce.ce_flags = @bitCast(class_flags);
            zce.num_interfaces = @intCast(interfaces.len);
            zce.unnamed_0.parent = @ptrCast(@constCast(class_pce));
            zce.unnamed_1.create_object = @ptrCast(&createObject);
            zce.get_iterator = @ptrCast(&getIterator);
            zce.get_static_method = @ptrCast(&getMethod);
            zce.unnamed_2.interfaces = switch (interfaces.len) {
                0 => null,
                else => @ptrCast(@constCast(&interfaces)),
            };
            if (@hasField(c.zend_class_entry, "default_object_handlers")) {
                zce.default_object_handlers = &Object.Custom(T).handlers;
            }
            pi._zend_hash_init(&zce.properties_info, c.HT_MIN_SIZE, null, true);
            pi._zend_hash_init(&zce.constants_table, c.HT_MIN_SIZE, @ptrCast(&freeConstant), true);
            pi._zend_hash_init(&zce.function_table, c.HT_MIN_SIZE, deref(&pi.zend_function_dtor), true);
            return self;
        }

        fn createObject(_: *@This()) callconv(.c) ?*Object {
            const custom_obj = Instance.create();
            return custom_obj.object();
        }

        fn getIterator(self: *@This(), this: *Value, by_ref: c_int) callconv(.c) ?*Object.Iterator {
            _ = self;
            _ = by_ref;
            return Instance.getIterator(this.object());
        }

        fn getMethod(self: *@This(), method_name: *String) callconv(.c) ?*const Function {
            return self.tryGetMethod(method_name) catch |err| throw: {
                failure.throw(err);
                break :throw null;
            };
        }

        fn tryGetMethod(self: *@This(), method_name: *String) !?*const Function {
            if (method_set.find(method_name)) |func| return func;
            if (!@hasDecl(T, "getStaticMethod")) return null;
            return T.getStaticMethod(self.custom(), method_name);
        }

        fn freeConstant(value: *Value) callconv(.c) void {
            const ptr = value.pointer();
            const constant: *Class.Constant = @ptrCast(@alignCast(ptr));
            php_al.destroy(constant);
            constant.value().release();
        }

        pub const custom_type: php.util.api.custom.Type = .class;
        pub const Static = php.util.api.FindStatic(T);
        pub const Instance = Object.Custom(T);

        const methods = php.util.symbol.MethodExporter(T, .static).get();
        const constants = php.util.symbol.ConstantExporter(T).get();
        const enums = php.util.symbol.EnumExporter(T).get();
        const classes = php.util.symbol.ClassExporter(T).get();

        const method_set = init: {
            const method_names = std.meta.fieldNames(@TypeOf(methods));
            var result: Object.MethodSet(method_names) = undefined;
            for (method_names) |method_name| {
                const method = @field(methods, method_name);
                @field(result.entries, method_name) = .init(.static(method_name), method, .{
                    .self_source = .{ .singleton = Static },
                    .is_static = true,
                });
            }
            break :init result;
        };

        var registered: ?*@This() = null;

        class_entry: Class,
    };
}
