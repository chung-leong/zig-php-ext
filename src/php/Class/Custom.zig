const std = @import("std");

const php = @import("../root.zig");
const c = php.c;
const deref = php.deref;
const pi = php.imports;
const php_al = php.allocator;
const Array = php.Array;
const Allocator = php.Allocator;
const Class = php.Class;
const Constant = php.Constant;
const errable = php.errable;
const failure = php.failure;
const Function = php.Function;
const Object = php.Object;
const Singleton = php.Singleton;
const String = php.String;
const Value = php.Value;
const ReturnType = php.util.ReturnType;

pub fn @"fn"(comptime T: type) type {
    return struct {
        pub fn name(self: *const @This()) *String {
            return self.class_entry.name();
        }

        pub fn class(self: *const @This()) *Class {
            return @ptrCast(@constCast(self));
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

        pub fn create(class_name: []const u8, parent_class: ?*Class) *@This() {
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
            const name_str: *String = .create(class_name);
            zce.* = .{};
            zce.type = c.ZEND_INTERNAL_CLASS;
            zce.refcount = 1;
            zce.name = @ptrCast(name_str);
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
            pi._zend_hash_init(&zce.properties_info, c.HT_MIN_SIZE, null, true);
            pi._zend_hash_init(&zce.constants_table, c.HT_MIN_SIZE, @ptrCast(&freeConstant), true);
            pi._zend_hash_init(&zce.function_table, c.HT_MIN_SIZE, deref(&pi.zend_function_dtor), true);
            self.registerConstants();
            return self;
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

        pub fn register(self: *@This()) !void {
            const cg = php.globals("compiler");
            const list: *Array = @ptrCast(cg.class_table);
            const lc_name = self.name().duplicateLowerCase();
            defer lc_name.release();
            if (list.has(lc_name)) return error.NameConflict;
            list.set(lc_name, .fromPointer(&self.class_entry.impl));
            self.addRef();
        }

        // pub fn unregister(self: *@This()) void {
        //     const cg = php.globals("compiler");
        //     const list: *Array = @ptrCast(cg.class_table);
        //     const lc_name = self.name().duplicateLowerCase();
        //     defer lc_name.release();
        //     list.delete(lc_name);
        // }

        pub fn initStatic() !void {
            if (Static != NoStatic) try Singleton(Static).init();
        }

        pub fn deinitStatic() void {
            if (Static != NoStatic) Singleton(Static).deinit();
        }

        pub fn registerConstants(self: *@This()) void {
            const st = @typeInfo(@TypeOf(constants)).@"struct";
            const arr = self.class().constants();
            inline for (st.field_names) |field_name| {
                const value = @field(constants, field_name);
                const constant: *Constant = .create(field_name, value);
                constant.attach(arr);
            }
        }

        fn createObject(self: *@This()) callconv(.c) ?*Object {
            const result = Instance.create(self.class());
            const custom_obj = switch (@typeInfo(@TypeOf(result))) {
                .error_union => result catch |err| {
                    failure.throw(err);
                    return null;
                },
                else => result,
            };
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
            const constant: *Constant = @ptrCast(@alignCast(ptr));
            constant.name().release();
            constant.value().release();
        }

        pub const Instance = Object.Custom(T);
        pub const Static = init: {
            var S: ?type = null;
            const decl_names = std.meta.declarations(T);
            for (decl_names) |decl_name| {
                if (std.mem.startsWith(u8, decl_name, "static ")) {
                    const Decl = @TypeOf(@field(T, decl_name));
                    if (@typeInfo(Decl) == .@"fn") {
                        const f = @typeInfo(Decl).@"fn";
                        const arg0_type: ?type = find: {
                            if (f.param_types.len > 0) {
                                if (f.param_types[0]) |PT| break :find PT;
                            }
                            break :find null;
                        };
                        const arg0_target_type: ?type = find: {
                            const Arg0 = arg0_type orelse break :find null;
                            switch (@typeInfo(Arg0)) {
                                .pointer => |pt| if (pt.size == .one) break :find pt.child,
                                else => {},
                            }
                            break :find null;
                        };
                        if (arg0_target_type) |New| {
                            if (S) |Current| {
                                if (New != Current) @compileError("Multiple static type detected: " ++ @typeName(Current) ++ ", " ++ @typeName(New));
                            } else {
                                S = New;
                            }
                        }
                    }
                }
            }
            break :init S orelse NoStatic;
        };
        const NoStatic = struct {};

        const methods = php.util.symbol.MethodExporter(T, .static).get();
        const constants = php.util.symbol.ConstantExporter(T).get();
        const enums = php.util.symbol.EnumExporter(T).get();
        const classes = php.util.symbol.ClassesExporter(T).get();

        const method_set = init: {
            const method_names = std.meta.fieldNames(@TypeOf(methods));
            var result: Object.MethodSet(method_names) = undefined;
            for (method_names) |method_name| {
                const method = @field(methods, method_name);
                @field(result.entries, method_name) = .init(method, .{
                    .self_source = .{ .singleton = Static },
                    .is_static = true,
                });
            }
            break :init result;
        };

        class_entry: Class align(@max(@alignOf(Class), @alignOf(Static))),

        comptime {
            if (@offsetOf(@This(), "class_entry") != 0) {
                @compileError("class_entry is in the wrong position");
            }
        }
    };
}
