const std = @import("std");

const php = @import("../root.zig");
const c = php.c;
const php_al = php.allocator;
const pi = php.imports;
const Array = php.Array;
const Class = php.Class;
const failure = php.failure;
const Function = php.Function;
const Object = php.Object;
const ClosureResult = Object.ClosureResult;
const GarbageCollectionResult = Object.GarbageCollectionResult;
const Opcode = Object.Opcode;
const PropertiesPurpose = Object.PropertiesPurpose;
const String = php.String;
const Value = php.Value;
const Access = Value.Access;
const State = Value.State;
const Kind = Value.Kind;
const argCount = php.util.argCount;
const ArgType = php.util.ArgType;
const WithoutError = php.util.WithoutError;
const errable = php.util.errable;

pub fn @"fn"(comptime T: type) type {
    return struct {
        pub fn object(self: *@This()) *Object {
            return @ptrCast(&self.php_object);
        }

        pub fn custom(self: *@This()) *T {
            return &self.custom_struct;
        }

        pub fn create(class: *Class) !*@This() {
            const self = try php_al.create(@This());
            errdefer php_al.destroy(self);
            // initialize the PHP portion
            pi.zend_object_std_init(@ptrCast(&self.php_object), @ptrCast(class));
            // handlers need to be set after zend_object_std_init() due to change in PHP 8.3
            self.php_object.handlers = &handlers;
            if (comptime !php.util.hasRequiredFields(T)) {
                // use default values when there are no required fields
                self.custom_struct = .{};
            } else {
                // __construct is required otherwise
                if (!@hasDecl(T, "getConstructor") and comptime !Methods.has("__construct")) {
                    @compileError("Object must have a constructor when it has fields without default value");
                }
            }
            return self;
        }

        pub fn getIterator(obj: *Object) ?*Object.Iterator {
            const self: *@This() = @ptrCast(obj);
            // TODO: allow allocator
            // TODO: make sure option struct has no required fields
            const iter = switch (@hasDecl(T, "iterate")) {
                true => switch (argCount(@TypeOf(T.iterate))) {
                    1 => self.iterate(),
                    2 => self.iterate(.{}),
                    else => @compileError("iterate() should have at most 1 argument containing options"),
                },
                false => switch (has_iterator) {
                    true => Object.Iterator.Properties(T, getter_names).init(obj),
                    false => return null,
                },
            };
            const Iterator = @TypeOf(iter);
            return Object.Iterator.Custom(Iterator).create(iter);
        }

        pub fn fromCustom(ptr: *T) *@This() {
            return @fieldParentPtr("custom_struct", ptr);
        }

        pub const Custom = T;
        pub const has_iterator = @hasDecl(T, "iterate") and getter_names.len > 0;
        pub const handler_protypes = .{
            .freeObject = fn (*T) void,
            .destroyObject = fn (*T) void,
            .cloneObject = fn (*T) ?*Object,
            .castObject = fn (*T, Kind) ?*Object,
            .readProperty = .{
                fn (*T, *String, Access) Value,
                fn (*T, *String, Access, ?[*]?*anyopaque) Value,
            },
            .writeProperty = .{
                fn (*T, *String, Value) void,
                fn (*T, *String, Value, ?[*]?*anyopaque) void,
            },
            .hasProperty = .{
                fn (*T, *String) bool,
                fn (*T, *String, ?[*]?*anyopaque) bool,
            },
            .unsetProperty = .{
                fn (*T, *String) void,
                fn (*T, *String, ?[*]?*anyopaque) void,
            },
            .getProperties = .{
                fn (*T, PropertiesPurpose) void,
            },
            .getPropertyPointer = .{
                fn (*T, *String, Access) ?*Value,
                fn (*T, *String, Access, ?[*]?*anyopaque) ?*Value,
            },
            .readDimension = fn (*T, Value, Access) Value,
            .writeDimension = fn (*T, Value, Value) void,
            .hasDimension = fn (*T, Value, bool) void,
            .unsetDimension = fn (*T, Value) void,
            .countElements = fn (*T, Value) usize,
            .getMethod = .{
                fn (*T, *String) usize,
                fn (*T, *String, Value) usize,
            },
            .getConstructor = fn (*T) *Function,
            .getClassName = fn (*T) *String,
            .compareWith = fn (*T, Value) c_int,
            .getClosure = fn (*T, bool) ClosureResult,
            .getGarbageCollection = fn (*T) GarbageCollectionResult,
            .doOperation = fn (u8, Value, Value) Value,
        };

        /// free_obj should release any resources the object holds, without freeing the
        /// object structure itself. The object does not need to be in a valid state after
        /// free_obj finishes running.
        ///
        /// free_obj will always be invoked, even if the object leaks or a fatal error
        /// occurs. However, during shutdown it may be called once the executor is no
        /// longer active, in which case execution of user code may be skipped.
        fn freeObject(obj: *Object) callconv(.c) void {
            tryFreeObject(obj) catch |err| {
                failure.throw(err);
            };
        }

        fn tryFreeObject(obj: *Object) !void {
            const self: *@This() = @ptrCast(obj);
            if (comptime Methods.has("__destruct")) {
                // TODO: don't call if __construct failed
                const prefix = comptime php.util.methodPrefix(.instance);
                const destruct = @field(T, prefix ++ "__destruct");
                errable(destruct(self.custom(), .{})) catch |err| {
                    failure.show(err);
                };
            } else {
                if (comptime php.util.hasPointer(T)) {
                    php.util.freeAny(self.custom_struct);
                }
            }
            return switch (@hasDecl(T, "freeObject")) {
                true => self.custom.freeObject(),
                false => {},
            };
        }

        /// destroyObject is called before free_obj. The object must remain in a valid state
        /// after destroyObject finishes running. Unlike freeObject, it is run prior to
        /// deactivation of the executor during shutdown, which allows user code to run.
        /// This handler is not guaranteed to be called (e.g. on fatal error), and as
        /// such should not be used to release resources or deallocate memory. Furthermore,
        /// releasing resources in this handler can break detection of memory leaks, as
        /// cycles may be broken early.
        ///
        /// destroyObject should be used *only* to call user destruction hooks, such as __destruct.
        fn destroyObject(obj: *Object) callconv(.c) void {
            tryDestroyObject(obj) catch |err| {
                failure.throw(err);
            };
        }

        fn tryDestroyObject(obj: *Object) !void {
            const self: *@This() = @ptrCast(obj);
            return switch (@hasDecl(T, "destroyObject")) {
                true => T.destroyObject(self.custom()),
                false => {},
            };
        }

        fn cloneObject(obj: *Object) callconv(.c) ?*Object {
            return tryCloneObject(obj) catch |err| {
                failure.throw(err);
                return null;
            };
        }

        fn tryCloneObject(obj: *Object) !?*Object {
            const self: *@This() = @ptrCast(obj);
            return switch (@hasDecl(T, "cloneObject")) {
                true => T.cloneObject(self.custom()),
                false => error.InvalidOperation,
            };
        }

        // Cast an object to some other type.
        fn castObject(obj: *Object, retval: *Value, zv_type: c_int) callconv(.c) c.zend_result {
            if (tryCastObject(obj, zv_type)) |value| {
                retval.* = value;
                return c.SUCCESS;
            } else |err| {
                failure.throw(err);
                return c.FAILURE;
            }
        }

        fn tryCastObject(obj: *Object, zv_type: c_int) !Value {
            const self: *@This() = @ptrCast(obj);
            return switch (@hasDecl(T, "castObject")) {
                true => T.castObject(self.custom(), .fromZvalType(zv_type)),
                false => error.InvalidOperation,
            };
        }

        fn readProperty(obj: *Object, name: *String, access: Access, cache_slot: [*]*anyopaque, retval: *Value) callconv(.c) *Value {
            if (tryReadProperty(obj, name, access, cache_slot)) |value| {
                retval.* = value;
            } else |err| {
                failure.throw(fieldError(obj, name, .read, err));
                retval.* = .fromNull();
            }
            return retval;
        }

        fn tryReadProperty(obj: *Object, name: *String, access: Access, cache_slot: [*]*anyopaque) !Value {
            const self: *@This() = @ptrCast(obj);
            return inline for (getter_names) |n| {
                if (name.matchSlice(n)) break self.callGetter(n);
            } else switch (@hasDecl(T, "readProperty")) {
                true => switch (argCount(@TypeOf(self.custom.readProperty))) {
                    4 => T.readProperty(self.custom(), name, access, cache_slot),
                    3 => T.readProperty(self.custom(), name, access),
                    else => unreachable,
                },
                false => error.UndefinedProperty,
            };
        }

        fn writeProperty(obj: *Object, name: *String, value: *Value, cache_slot: [*]*anyopaque) callconv(.c) *Value {
            tryWriteProperty(obj, name, value, cache_slot) catch |err| {
                failure.throw(fieldError(obj, name, .write, err));
            };
            return value;
        }

        fn tryWriteProperty(obj: *Object, name: *String, value: *Value, cache_slot: [*]*anyopaque) !void {
            const self: *@This() = @ptrCast(obj);
            return inline for (setter_names) |n| {
                if (name.matchSlice(n)) break self.callSetter(n, value);
            } else switch (@hasDecl(T, "writeProperty")) {
                true => switch (argCount(@TypeOf(T.writeProperty))) {
                    4 => T.writeProperty(self.custom(), name, value.*, cache_slot),
                    3 => T.writeProperty(self.custom(), name, value.*),
                    else => unreachable,
                },
                false => error.UndefinedProperty,
            };
        }

        fn hasProperty(obj: *Object, name: *String, state: State, cache_slot: [*]*anyopaque) callconv(.c) c_int {
            if (tryHasProperty(obj, name, cache_slot)) |found| {
                if (found) {
                    if (state == .not_null or state == .not_false) {
                        if (tryReadProperty(obj, name, .isset, cache_slot)) |value| {
                            if (state == .not_false) {
                                if (value.cast(.boolean).boolean() == false) return c.FAILURE;
                            } else {
                                if (value.isNull()) return c.FAILURE;
                            }
                        } else |err| {
                            failure.throw(fieldError(obj, name, .isset, err));
                            return c.FAILURE;
                        }
                    }
                    return c.SUCCESS;
                } else {
                    return c.FAILURE;
                }
            } else |err| {
                failure.throw(fieldError(obj, name, .isset, err));
                return c.FAILURE;
            }
        }

        fn tryHasProperty(obj: *Object, name: *String, cache_slot: [*]*anyopaque) !bool {
            const self: *@This() = @ptrCast(obj);
            return inline for (setter_names) |n| {
                if (name.matchSlice(n)) break true;
            } else switch (@hasDecl(T, "unsetProperty")) {
                true => switch (argCount(@TypeOf(self.custom.hasProperty))) {
                    3 => T.hasProperty(self.custom(), name, cache_slot),
                    2 => T.hasProperty(self.custom(), name),
                    else => unreachable,
                },
                false => false,
            };
        }

        fn unsetProperty(obj: *Object, name: *String, cache_slot: [*]*anyopaque) callconv(.c) void {
            return tryUnsetProperty(obj, name, cache_slot) catch |err| {
                failure.throw(fieldError(obj, name, .unset, err));
            };
        }

        fn tryUnsetProperty(obj: *Object, name: *String, cache_slot: [*]*anyopaque) !void {
            const self: *@This() = @ptrCast(obj);
            return inline for (setter_names) |n| {
                if (name.matchSlice(n)) break self.callSetterWithNull(n);
            } else switch (@hasDecl(T, "unsetProperty")) {
                true => switch (argCount()) {
                    3 => T.unsetProperty(self.custom(), name, cache_slot),
                    2 => T.unsetProperty(self.custom(), name),
                    else => unreachable,
                },
                false => error.UndefinedProperty,
            };
        }

        fn getProperties(obj: *Object) callconv(.c) ?*Array {
            const result = tryGetPropertiesFor(obj, .default) catch |err| {
                failure.throw(err);
                return null;
            };
            // caller expects array without refcount
            if (result) |arr| arr.subtractRef();
            return result;
        }

        fn getPropertiesFor(obj: *Object, purpose: PropertiesPurpose) callconv(.c) ?*Array {
            return tryGetPropertiesFor(obj, purpose) catch |err| {
                failure.throw(err);
                return null;
            };
        }

        fn tryGetPropertiesFor(obj: *Object, purpose: PropertiesPurpose) !?*Array {
            const self: *@This() = @ptrCast(obj);
            const Self = @This();
            const from = struct {
                pub fn getters(s: *Self) !?*Array {
                    return switch (getter_names.len > 0) {
                        true => get: {
                            const list = Array.create();
                            inline for (getter_names) |n| {
                                const result = try s.callGetter(n);
                                defer result.release();
                                list.set(String.static(n), result);
                            }
                            break :get list;
                        },
                        false => null,
                    };
                }

                pub fn handler(s: *Self, p: PropertiesPurpose) !?*Array {
                    return switch (@hasDecl(T, "getProperties")) {
                        true => s.custom.getProperties(p),
                        false => null,
                    };
                }
            };
            const list1 = try from.getters(self);
            const list2 = try from.handler(self, purpose);
            if (list1) |arr1| {
                if (list2) |arr2| {
                    // append arr2 to arr1 then release arr2
                    defer arr2.release();
                    var iter = arr2.iterate(.{});
                    while (iter.next()) |value| {
                        arr1.set(iter.key(), value);
                    }
                }
                return list1;
            } else {
                return list2;
            }
        }

        fn getPropertyPointer(obj: *Object, name: *String, access: Access, cache_slot: [*]*anyopaque) callconv(.c) ?*Value {
            return tryGetPropertyPointer(obj, name, access, cache_slot) catch |err| {
                failure.throw(err);
                return null;
            };
        }

        fn tryGetPropertyPointer(obj: *Object, name: *String, access: Access, cache_slot: [*]*anyopaque) !?*Value {
            _ = cache_slot;
            const self: *@This() = @ptrCast(obj);
            return switch (@hasDecl(T, "getPropertyPointer")) {
                true => T.getPropertyPointer(self.custom(), name, access),
                false => error.InvalidOperation,
            };
        }

        fn readDimension(obj: *Object, offset: *Value, access: Value.Access, retval: *Value) callconv(.c) *Value {
            if (tryReadDimension(obj, offset, access)) |value| {
                retval.* = value;
            } else |err| {
                failure.throw(err);
                retval.* = .fromNull();
            }
            return retval;
        }

        fn tryReadDimension(obj: *Object, offset: *Value, access: Value.Access) !Value {
            const self: *@This() = @ptrCast(obj);
            return switch (@hasDecl(T, "readDimension")) {
                true => T.readDimension(self.custom(), offset.*, access),
                false => error.InvalidOperation,
            };
        }

        fn writeDimension(obj: *Object, offset: *Value, value: *Value) callconv(.c) void {
            tryWriteDimension(obj, offset, value) catch |err| {
                failure.throw(err);
            };
        }

        fn tryWriteDimension(obj: *Object, offset: *Value, value: *Value) !void {
            const self: *@This() = @ptrCast(obj);
            return switch (@hasDecl(T, "writeDimension")) {
                true => T.writeDimension(self.custom(), offset.*, value.*),
                false => error.InvalidOperation,
            };
        }

        fn hasDimension(obj: *Object, offset: *Value, check_empty: c_int) callconv(.c) c_int {
            if (tryHasDimension(obj, offset, check_empty)) |state| {
                return if (state) 1 else 0;
            } else |err| {
                failure.throw(err);
                return 0;
            }
        }

        fn tryHasDimension(obj: *Object, offset: *Value, check_empty: c_int) !bool {
            const self: *@This() = @ptrCast(obj);
            return switch (@hasDecl(T, "hasDimension")) {
                true => T.hasDimension(self.custom(), offset.*, check_empty != 0),
                false => error.InvalidOperation,
            };
        }

        fn unsetDimension(obj: *Object, offset: *Value) callconv(.c) void {
            tryUnsetDimension(obj, offset) catch |err| {
                failure.throw(err);
            };
        }

        fn tryUnsetDimension(obj: *Object, offset: *Value) !void {
            const self: *@This() = @ptrCast(obj);
            return switch (@hasDecl(T, "unsetDimension")) {
                true => T.unsetDimension(self.custom(), offset),
                false => error.InvalidOperation,
            };
        }

        fn countElements(obj: *Object, count: *c_long) c.zend_result {
            if (tryCountElements(obj)) |num| {
                count.* = @intCast(num);
                return c.SUCCESS;
            } else |err| {
                failure.throw(err);
                return c.FAILURE;
            }
        }

        fn tryCountElements(obj: *Object) !usize {
            const self: *@This() = @ptrCast(obj);
            return switch (@hasDecl(T, "countElements")) {
                true => T.countElements(self.custom()),
                false => error.InvalidOperation,
            };
        }

        /// Get method
        fn getMethod(obj_ptr: **Object, name: *String, key: *Value) callconv(.c) ?*const Function {
            return tryGetMethod(obj_ptr, name, key) catch |err| {
                failure.throw(err);
                return null;
            };
        }

        fn tryGetMethod(obj_ptr: **Object, name: *String, key: *Value) !?*const Function {
            // TODO: use key for case insensitivity
            _ = key;
            const self: *@This() = @ptrCast(obj_ptr.*);
            return methods.find(name) orelse switch (@hasDecl(T, "getMethod")) {
                true => T.getMethod(self.custom(), name),
                false => error.UndefinedMethod,
            };
        }

        /// Get constructor
        fn getConstructor(obj: *Object) callconv(.c) ?*const Function {
            return tryGetConstructor(obj) catch |err| {
                failure.throw(err);
                return null;
            };
        }

        fn tryGetConstructor(obj: *Object) !?*const Function {
            const self: *@This() = @ptrCast(obj);
            // return __construct if it's there
            if (comptime Methods.has("__construct")) {
                return methods.get("__construct");
            }
            return switch (@hasDecl(T, "getConstructor")) {
                true => T.getConstructor(self.custom()),
                false => null,
            };
        }

        /// Get class name for display in var_dump and other debugging functions.
        fn getClassName(obj: *Object) callconv(.c) *String {
            return tryGetClassName(obj) catch |err| {
                failure.throw(err);
                return "(error)";
            };
        }

        fn tryGetClassName(obj: *Object) !*String {
            const self: *@This() = @ptrCast(obj);
            return switch (@hasDecl(T, "getClassName")) {
                true => T.getClassName(self.custom()),
                false => obj.class().name(),
            };
        }

        /// Compare object to value given
        fn compareWith(value_ptr1: *Value, value_ptr2: *Value) callconv(.c) c_int {
            const obj, const value, const multiplier: c_int = init: {
                if (value_ptr1.kind() == .object) {
                    const obj1 = value_ptr1.object();
                    if (@intFromPtr(obj1.impl.handlers.*.compare) == @intFromPtr(&compareWith)) {
                        break :init .{ obj1, value_ptr2.*, 1 };
                    }
                }
                if (value_ptr2.kind() == .object) {
                    const obj2 = value_ptr2.object();
                    if (@intFromPtr(obj2.impl.handlers.*.compare) == @intFromPtr(&compareWith)) {
                        break :init .{ obj2, value_ptr1.*, -1 };
                    }
                }
                unreachable;
            };
            if (tryCompareWith(obj, value)) |result| {
                return result * multiplier;
            } else |err| {
                failure.throw(err);
                return 1;
            }
        }

        fn tryCompareWith(obj: *Object, value: Value) !c_int {
            const self: *@This() = @ptrCast(obj);
            return switch (@hasDecl(T, "compareWith")) {
                true => self.custom.compareWith(value),
                false => error.IllegalOperation,
            };
        }

        fn getClosure(obj: *Object, class_ptr: *?*Class, func_ptr: *?*Function, obj_ptr: *?*Object, check_only: bool) callconv(.c) c.zend_result {
            if (tryGetClosure(obj, check_only)) |closure| {
                class_ptr.* = closure.class;
                func_ptr.* = closure.function;
                obj_ptr.* = closure.object;
                return c.SUCCESS;
            } else |err| {
                failure.throw(err);
                return c.FAILURE;
            }
        }

        fn tryGetClosure(obj: *Object, check_only: bool) !ClosureResult {
            const self: *@This() = @ptrCast(obj);
            return switch (@hasDecl(T, "getClosure")) {
                true => self.custom.getClosure(check_only),
                false => error.IllegalOperation,
            };
        }

        fn getGarbageCollection(obj: *Object, table: *?[*]const *Value, n: *c_int) callconv(.c) ?*const Array {
            const gc = tryGetGarbageCollection(obj) catch |err| get: {
                failure.throw(err);
                break :get .{};
            };
            table.* = if (gc.slice.len > 0) gc.slice.ptr else null;
            n.* = @intCast(gc.slice.len);
            return gc.array;
        }

        fn tryGetGarbageCollection(obj: *Object) !GarbageCollectionResult {
            const self: *@This() = @ptrCast(obj);
            return switch (@hasDecl(T, "getGarbageCollection")) {
                true => self.custom.getGarbageCollection(self.custom()),
                false => GarbageCollectionResult{},
            };
        }

        fn doOperation(opcode: Opcode, retval: *Value, op1: *Value, op2: *Value) callconv(.c) c.zend_result {
            if (tryDoOperation(opcode, op1, op2)) |value| {
                retval.* = value;
                return c.SUCCESS;
            } else |err| {
                failure.throw(err);
                retval.* = .fromNull();
                return c.FAILURE;
            }
        }

        fn tryDoOperation(opcode: Opcode, op1: *Value, op2: *Value) !Value {
            return switch (@hasDecl(T, "doOperation")) {
                true => T.doOperation(opcode, op1.*, op2.*),
                false => error.IllegalOperation,
            };
        }

        fn fieldError(obj: *Object, name: *String, access: Value.Access, err: anytype) error{FailureReported} {
            if (failure.match(err, error.FailureReported)) {
                return error.FailureReported;
            } else if (failure.match(err, error.UndefinedProperty)) {
                return failure.report("no field named '{s}' in {s}", .{
                    name.slice(),
                    obj.class().name().slice(),
                });
            } else {
                const message = failure.acquireMessage(err);
                defer failure.freeMessage(message);
                return failure.report("unable to {s} field '{s}' in {s}: {s}", .{
                    @tagName(access),
                    name.slice(),
                    obj.class().name().slice(),
                    message,
                });
            }
        }

        fn callGetter(self: *@This(), comptime prop_name: []const u8) !Value {
            const get = @field(T, "get " ++ prop_name);
            const payload = get(self.custom());
            return Value.fromAny(payload);
        }

        fn callSetter(self: *@This(), comptime prop_name: []const u8, value: *Value) !void {
            const set = @field(T, "set " ++ prop_name);
            const PT = ArgType(@TypeOf(set), 1);
            const payload = try value.convertTo(PT);
            return set(self.custom(), payload);
        }

        fn callSetterWithNull(self: *@This(), comptime prop_name: []const u8) !void {
            const set = @field(T, "set " ++ prop_name);
            const PT = ArgType(@TypeOf(set), 1);
            return if (@typeInfo(PT) == .optional) set(self.custom(), null) else error.InvalidOperation;
        }

        const getter_names = php.util.getterNames(T, .instance);
        const setter_names = php.util.setterNames(T, .instance);
        const method_names = php.util.methodNames(T, .instance);
        const Methods = Object.MethodSet(method_names);
        const ObjectLite = init: {
            const st = @typeInfo(c.zend_object).@"struct";
            const len = st.field_names.len;
            const field_names = st.field_names[0 .. len - 1];
            const field_types = st.field_types[0 .. len - 1];
            const field_attrs = st.field_attrs[0 .. len - 1];
            break :init @Struct(st.layout, null, field_names, field_types, field_attrs);
        };
        const methods: Methods = .fromType(T, php.util.methodPrefix(.instance));
        const handlers: Object.Handlers = .{
            .free_obj = @ptrCast(&freeObject),
            .dtor_obj = @ptrCast(&destroyObject),
            .clone_obj = @ptrCast(&cloneObject),
            .read_property = @ptrCast(&readProperty),
            .write_property = @ptrCast(&writeProperty),
            .read_dimension = @ptrCast(&readDimension),
            .write_dimension = @ptrCast(&writeDimension),
            .get_property_ptr_ptr = @ptrCast(&getPropertyPointer),
            .has_property = @ptrCast(&hasProperty),
            .unset_property = @ptrCast(&unsetProperty),
            .get_properties = @ptrCast(&getProperties),
            .get_properties_for = @ptrCast(&getPropertiesFor),
            .has_dimension = @ptrCast(&hasDimension),
            .unset_dimension = @ptrCast(&unsetDimension),
            .get_method = @ptrCast(&getMethod),
            .get_constructor = @ptrCast(&getConstructor),
            .get_class_name = @ptrCast(&getClassName),
            .cast_object = @ptrCast(&castObject),
            .count_elements = @ptrCast(&countElements),
            .get_closure = @ptrCast(&getClosure),
            .get_gc = @ptrCast(&getGarbageCollection),
            .do_operation = @ptrCast(&doOperation),
            .compare = @ptrCast(&compareWith),
        };

        php_object: ObjectLite align(@max(@alignOf(ObjectLite), @alignOf(T))),
        custom_struct: T,

        comptime {
            if (@offsetOf(@This(), "php_object") != 0) {
                @compileError("php_object is in the wrong position");
            }
        }
    };
}
