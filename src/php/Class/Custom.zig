const std = @import("std");

const php = @import("../root.zig");
const c = php.c;
const deref = php.deref;
const pi = php.imports;
const php_al = php.allocator;
const errable = php.errable;
const Array = php.Array;
const Allocator = php.Allocator;
const Class = php.Class;
const failure = php.failure;
const Function = php.Function;
const Object = php.Object;
const String = php.String;
const Value = php.Value;
const ReturnType = php.util.ReturnType;

pub fn @"fn"(comptime T: type) type {
    const decl_names = std.meta.declarations(T);
    return struct {
        pub fn name(self: *const @This()) *String {
            return self.class_entry.name();
        }

        pub fn custom(self: *@This()) *T {
            return &self.custom_struct;
        }

        pub fn parent(self: *const @This()) *Class {
            return self.class_entry.parent();
        }

        pub fn flags(self: *const @This()) Class.Flags {
            return self.class_entry.flags();
        }

        pub fn create(class_name: *String, parent_class: ?*Class) *@This() {
            const self = php_al.create(@This()) catch unreachable;
            errdefer php_al.destroy(self);
            self.* = try init(class_name, parent_class);
            return self;
        }

        pub fn init(class_name: *String, parent_class: ?*Class) @This() {
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
            var self: @This() = undefined;
            const class_flags: Class.Flags = .{
                .linked = true,
                .no_dynamic_properties = true,
                .resolved_interfaces = true,
                .resolved_parent = true,
                .not_serializable = !@hasDecl(T, "serialize"),
                .abstract = decl_names.len == 0,
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
            pi._zend_hash_init(&zce.properties_info, c.HT_MIN_SIZE, null, false);
            pi._zend_hash_init(&zce.constants_table, c.HT_MIN_SIZE, null, false);
            pi._zend_hash_init(&zce.function_table, c.HT_MIN_SIZE, deref(&pi.zend_function_dtor), false);
            self.custom_struct = switch (@hasDecl(T, "staticInit")) {
                true => switch (@typeInfo(ReturnType(@TypeOf(T.staitcInit)))) {
                    .error_union => try .staitcInit(),
                    else => .staitcInit(),
                },
                false => if (Static == void) {} else .{},
            };
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

        pub fn unregister(self: *@This()) void {
            const cg = php.globals("compiler");
            const list: *Array = @ptrCast(cg.class_table);
            const lc_name = self.name().duplicateLowerCase();
            defer lc_name.release();
            list.delete(lc_name);
        }

        pub fn createObject(class: *Class) callconv(.c) ?*Object {
            const result = Instance.create(class);
            const custom_obj = switch (@typeInfo(@TypeOf(result))) {
                .error_union => result catch |err| {
                    failure.throw(err);
                    return null;
                },
                else => result,
            };
            return custom_obj.object();
        }

        pub fn getIterator(class: *Class, this: *Value, by_ref: c_int) callconv(.c) ?*Object.Iterator {
            _ = class;
            _ = by_ref;
            return Instance.getIterator(this.object());
        }

        pub fn getMethod(class: *Class, method_name: *String) callconv(.c) ?*const Function {
            return tryGetMethod(class, method_name) catch |err| throw: {
                failure.throw(err);
                break :throw null;
            };
        }

        fn tryGetMethod(class: *Class, method_name: *String) !?*const Function {
            const self: *@This() = @ptrCast(class);
            if (methods.find(method_name)) |func| return func;
            if (!@hasDecl(T, "getStaticMethod")) return null;
            return T.getStaticMethod(self.custom(), method_name);
        }

        pub const Static = init: {
            var S: ?type = null;
            for (.{
                .{ .names = getter_names, .prefix = php.util.getterPrefix(.static) },
                .{ .names = setter_names, .prefix = php.util.setterPrefix(.static) },
                .{ .names = method_names, .prefix = php.util.methodPrefix(.static) },
            }) |section| {
                for (section.names) |n| {
                    const Decl = @TypeOf(@field(T, section.prefix ++ n));
                    const New = switch (@typeInfo(Decl)) {
                        .pointer => |pt| pt.child,
                        else => @compileError("Self must be a pointer, received: " ++ @typeName(Decl)),
                    };
                    if (S) |Current| {
                        if (New != Current) @compileError("Multiple static type detected: " ++ @typeName(Current) ++ ", " ++ @typeName(New));
                    } else {
                        S = New;
                    }
                }
            }
            break :init S orelse void;
        };
        pub const Instance = Object.Custom(T);

        const getter_names = php.util.getterNames(T, .static);
        const setter_names = php.util.setterNames(T, .static);
        const method_names = php.util.methodNames(T, .static);
        const Methods = Object.MethodSet(method_names);
        const methods: Methods = .fromType(T, php.util.methodPrefix(.static));

        class_entry: Class align(@max(@alignOf(Class), @alignOf(Static))),
        custom_struct: Static,

        comptime {
            if (@offsetOf(@This(), "class_entry") != 0) {
                @compileError("class_entry is in the wrong position");
            }
        }
    };
}
