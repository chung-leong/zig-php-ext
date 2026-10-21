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
const Iterator = Object.Iterator;
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
const WithoutError = php.util.WithoutError;
const errable = php.util.errable;

pub fn @"fn"(comptime T: type) type {
    return struct {
        pub fn object(self: *const @This()) *Object {
            return @ptrCast(@constCast(&self.php_object));
        }

        pub fn custom(self: *const @This()) *T {
            return @constCast(&self.custom_struct);
        }

        pub fn fromCustom(custom_ptr: *const T) *@This() {
            const self: *const @This() = @fieldParentPtr("custom_struct", custom_ptr);
            std.debug.assert(is(self.object()));
            return @constCast(self);
        }

        pub fn is(obj: *const Object) bool {
            return @intFromPtr(obj.impl.handlers) == @intFromPtr(&handlers);
        }

        pub fn create(class: *const Class) !*@This() {
            const self = try php_al.create(@This());
            errdefer php_al.destroy(self);
            // initialize the PHP portion
            pi.zend_object_std_init(@ptrCast(&self.php_object), @ptrCast(@constCast(class)));
            // handlers need to be set after zend_object_std_init() due to change in PHP 8.3
            self.php_object.handlers = &handlers;
            // set fields of custom struct to their default values (when available)
            inline for (comptime std.meta.fieldNames(T)) |field_name| {
                if (php.util.getFieldDefaultValue(T, field_name)) |def_value| {
                    @field(self.custom_struct, field_name) = def_value;
                }
            }
            return self;
        }

        pub fn getIterator(obj: *Object) ?*Iterator {
            return tryGetIterator(obj) catch |err| {
                failure.throw(err);
                return null;
            };
        }

        fn tryGetIterator(obj: *Object) !?*Iterator {
            const self: *@This() = @ptrCast(obj);
            if (!has_iterator) return null;
            if (@hasDecl(T, "getIterator")) {
                return T.getIterator(self.custom());
            }
            const result = switch (@hasDecl(T, "iterate")) {
                true => switch (comptime argCount(@TypeOf(T.iterate))) {
                    1 => T.iterate(self.custom()),
                    // TODO: make sure option struct has no required fields
                    2 => T.iterate(self.custom(), .{}),
                    else => @compileError("iterate() should have at most 1 argument containing options"),
                },
                false => create: {
                    const arr = getPropertiesFor(obj, .default) orelse return null;
                    defer arr.release();
                    break :create PropertyIterator.init(arr);
                },
            };
            const iter = try errable(result);
            const custom_iter = try Iterator.Custom(@TypeOf(iter)).create(iter);
            return custom_iter.iterator();
        }

        pub const Custom = T;
        pub const has_iterator = init: {
            if (@hasDecl(T, "getIterator")) break :init true;
            if (@hasDecl(T, "iterate")) break :init true;
            if (@hasDecl(T, "getProperties")) break :init true;
            if (std.meta.fieldNames(@TypeOf(getters)).len > 0) break :init true;
            break :init false;
        };
        pub const handler_protypes = .{
            .freeObject = fn (*T) void,
            .destroyObject = fn (*T) void,
            .cloneObject = fn (*T) *Object,
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
                fn (*T, *String) *const Function,
                fn (*T, *String, *String) *const Function,
            },
            .getConstructor = fn (*T) *Function,
            .getClassName = fn (*T) *String,
            .compareWith = fn (*T, Value) c_int,
            .getClosure = fn (*T, bool) ClosureResult,
            .getGarbageCollection = fn (*T) GarbageCollectionResult,
            .doOperation = fn (u8, Value, Value) Value,
        };

        fn construct(obj: *Object, args: init_fn.Args) !void {
            const self: *@This() = @ptrCast(obj);
            if (init_fn.exists) {
                if (init_fn.by_value) {
                    self.custom_struct = try errable(if (init_fn.uses_args) T.init(args) else T.init());
                } else {
                    const ptr = &self.custom_struct;
                    try errable(if (init_fn.uses_args) T.initSelf(ptr, args) else T.initSelf(ptr));
                }
            } else {
                self.custom_struct = .{};
                inline for (comptime std.meta.fieldNames(@TypeOf(setters))) |setter_name| {
                    const set = @field(setters, setter_name);
                    const arg = @field(args, setter_name);
                    // skip if argument is null (leaving default value intact)
                    if (arg) |value| try errable(set(self.custom(), value));
                }
            }
            self.flags.initialized = true;
        }

        fn destruct(obj: *Object) void {
            const self: *@This() = @ptrCast(obj);
            switch (deinit_fn.exists) {
                true => T.deinit(self.custom()),
                false => {
                    if (comptime php.util.hasPointer(T)) {
                        // free memory allocated by setters
                        php.util.freeAny(self.custom_struct);
                    }
                },
            }
        }

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
            // perform standard destruction process unless custom constructor is used
            if (!@hasDecl(T, "getConstructor")) {
                defer if (self.flags.initialized) destruct(obj);
            }
            return switch (@hasDecl(T, "freeObject")) {
                true => T.freeObject(self.custom()),
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
                false => switch (@hasDecl(T, "clone")) {
                    true => clone: {
                        const copy = try create(obj.class());
                        copy.custom_struct = try T.clone(self.custom());
                        copy.flags.initialized = true;
                        break :clone copy.object();
                    },
                    false => error.InvalidOperation,
                },
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

        fn readProperty(obj: *Object, name: *String, access: Access, cache_slot: ?[*]?*anyopaque, retval: *Value) callconv(.c) *Value {
            if (tryReadProperty(obj, name, access, cache_slot)) |value| {
                retval.* = value;
            } else |err| {
                failure.throw(fieldError(obj, name, .read, err));
                retval.* = .fromNull();
            }
            return retval;
        }

        fn tryReadProperty(obj: *Object, name: *String, access: Access, cache_slot: ?[*]?*anyopaque) !Value {
            const self: *@This() = @ptrCast(obj);
            return inline for (comptime std.meta.fieldNames(@TypeOf(getters))) |getter_name| {
                if (name.matchSlice(getter_name)) break self.callGetter(getter_name);
            } else switch (@hasDecl(T, "readProperty")) {
                true => switch (comptime argCount(@TypeOf(T.readProperty))) {
                    4 => T.readProperty(self.custom(), name, access, cache_slot),
                    3 => T.readProperty(self.custom(), name, access),
                    else => unreachable,
                },
                false => error.Undefined,
            };
        }

        fn writeProperty(obj: *Object, name: *String, value: *Value, cache_slot: ?[*]?*anyopaque) callconv(.c) ?*Value {
            tryWriteProperty(obj, name, value, cache_slot) catch |err| {
                failure.throw(fieldError(obj, name, .write, err));
            };
            return value;
        }

        fn tryWriteProperty(obj: *Object, name: *String, value: *Value, cache_slot: ?[*]?*anyopaque) !void {
            const self: *@This() = @ptrCast(obj);
            return inline for (comptime std.meta.fieldNames(@TypeOf(setters))) |setter_name| {
                if (name.matchSlice(setter_name)) break self.callSetter(setter_name, value.*);
            } else switch (@hasDecl(T, "writeProperty")) {
                true => switch (comptime argCount(@TypeOf(T.writeProperty))) {
                    4 => T.writeProperty(self.custom(), name, value.*, cache_slot),
                    3 => T.writeProperty(self.custom(), name, value.*),
                    else => unreachable,
                },
                false => error.Undefined,
            };
        }

        fn hasProperty(obj: *Object, name: *String, state: State, cache_slot: ?[*]?*anyopaque) callconv(.c) c_int {
            if (tryHasProperty(obj, name, cache_slot)) |found| {
                if (found) {
                    if (state == .not_null or state == .not_false) {
                        if (tryReadProperty(obj, name, .isset, cache_slot)) |value| {
                            defer value.release();
                            if (state == .not_false) {
                                if (value.cast(.boolean).boolean() == false) return c.FAILURE;
                            } else {
                                if (value.isNull()) return c.FAILURE;
                            }
                        } else |err| {
                            failure.throw(fieldError(obj, name, .isset, err));
                            return 0;
                        }
                    }
                    return 1;
                } else {
                    return 0;
                }
            } else |err| {
                failure.throw(fieldError(obj, name, .isset, err));
                return 0;
            }
        }

        fn tryHasProperty(obj: *Object, name: *String, cache_slot: ?[*]?*anyopaque) !bool {
            const self: *@This() = @ptrCast(obj);
            return inline for (comptime std.meta.fieldNames(@TypeOf(getters))) |getter_name| {
                if (name.matchSlice(getter_name)) break true;
            } else switch (@hasDecl(T, "hasProperty")) {
                true => switch (comptime argCount(@TypeOf(T.hasProperty))) {
                    3 => T.hasProperty(self.custom(), name, cache_slot),
                    2 => T.hasProperty(self.custom(), name),
                    else => unreachable,
                },
                false => false,
            };
        }

        fn unsetProperty(obj: *Object, name: *String, cache_slot: ?[*]?*anyopaque) callconv(.c) void {
            return tryUnsetProperty(obj, name, cache_slot) catch |err| {
                failure.throw(fieldError(obj, name, .unset, err));
            };
        }

        fn tryUnsetProperty(obj: *Object, name: *String, cache_slot: ?[*]?*anyopaque) !void {
            const self: *@This() = @ptrCast(obj);
            return inline for (comptime std.meta.fieldNames(@TypeOf(setters))) |setter_name| {
                if (name.matchSlice(setter_name)) break self.callSetterWithNull(setter_name);
            } else switch (@hasDecl(T, "unsetProperty")) {
                true => switch (comptime argCount(@TypeOf(T.unsetProperty))) {
                    3 => T.unsetProperty(self.custom(), name, cache_slot),
                    2 => T.unsetProperty(self.custom(), name),
                    else => unreachable,
                },
                false => error.Undefined,
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
            const getter_names = comptime std.meta.fieldNames(@TypeOf(getters));
            const from = struct {
                pub fn getters(s: *Self) !?*Array {
                    return switch (getter_names.len > 0) {
                        true => get: {
                            const list = Array.create();
                            inline for (getter_names) |getter_name| {
                                const result = try s.callGetter(getter_name);
                                defer result.release();
                                list.set(String.static(getter_name), result);
                            }
                            break :get list;
                        },
                        false => null,
                    };
                }

                pub fn handler(s: *Self, p: PropertiesPurpose) !?*Array {
                    return switch (@hasDecl(T, "getProperties")) {
                        true => T.getProperties(s.custom(), p),
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

        fn getPropertyPointer(obj: *Object, name: *String, access: Access, cache_slot: ?[*]?*anyopaque) callconv(.c) ?*Value {
            return tryGetPropertyPointer(obj, name, access, cache_slot) catch |err| {
                failure.throw(err);
                return null;
            };
        }

        fn tryGetPropertyPointer(obj: *Object, name: *String, access: Access, cache_slot: ?[*]?*anyopaque) !?*Value {
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
                true => T.unsetDimension(self.custom(), offset.*),
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
                // throw the error unless it's `Undefined`
                if (!failure.match(err, error.Undefined)) {
                    failure.throw(err);
                }
                return null;
            };
        }

        fn tryGetMethod(obj_ptr: **Object, name: *String, key: *Value) !*const Function {
            const self: *@This() = @ptrCast(obj_ptr.*);
            return method_set.find(key.string()) orelse switch (@hasDecl(T, "getMethod")) {
                true => switch (comptime argCount(@TypeOf(T.getMethod))) {
                    2 => T.getMethod(self.custom(), key.string()),
                    3 => T.getMethod(self.custom(), name, key.string()),
                    else => unreachable,
                },
                false => error.Undefined,
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
            return switch (@hasDecl(T, "getConstructor")) {
                true => T.getConstructor(self.custom()),
                false => &constructor,
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
                false => obj.class().name().retain(),
            };
        }

        /// Compare object to value given
        fn compareWith(value_ptr1: *Value, value_ptr2: *Value) callconv(.c) c_int {
            const obj, const value, const multiplier: c_int = init: {
                if (value_ptr1.kind() == .object) {
                    const obj1 = value_ptr1.object();
                    if (is(obj1)) {
                        break :init .{ obj1, value_ptr2.*, 1 };
                    }
                }
                if (value_ptr2.kind() == .object) {
                    const obj2 = value_ptr2.object();
                    if (is(obj2)) {
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
                true => T.compareWith(self.custom(), value),
                false => error.IllegalOperation,
            };
        }

        fn getClosure(obj: *Object, class_ptr: *?*const Class, func_ptr: *?*const Function, obj_ptr: *?*const Object, check_only: bool) callconv(.c) c.zend_result {
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
                true => T.getClosure(self.custom(), check_only),
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
                true => T.getGarbageCollection(self.custom()),
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
            } else if (failure.match(err, error.Undefined)) {
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

        fn callGetter(self: *@This(), comptime getter_name: []const u8) !Value {
            const get = @field(getters, getter_name);
            const payload = get(self.custom());
            return Value.fromAny(payload);
        }

        fn callSetter(self: *@This(), comptime setter_name: []const u8, value: Value) !void {
            const set = @field(setters, setter_name);
            const PT = php.util.ArgType(@TypeOf(set), 1);
            const payload = try value.convertTo(PT);
            return set(self.custom(), payload);
        }

        fn callSetterWithNull(self: *@This(), comptime setter_name: []const u8) !void {
            const set = @field(setters, setter_name);
            const PT = php.util.ArgType(@TypeOf(set), 1);
            return if (@typeInfo(PT) == .optional) set(self.custom(), null) else error.CannotBeNull;
        }

        fn isCustomClass(comptime Decl: type) bool {
            return switch (@typeInfo(Decl)) {
                .@"struct" => @hasField(Decl, "class_entry") and @FieldType(Decl, "class_entry") == Class,
                else => false,
            };
        }

        const ObjectLite = init: {
            const st = @typeInfo(c.zend_object).@"struct";
            const len = st.field_names.len;
            const field_names = st.field_names[0 .. len - 1];
            const field_types = st.field_types[0 .. len - 1];
            const field_attrs = st.field_attrs[0 .. len - 1];
            break :init @Struct(st.layout, null, field_names, field_types, field_attrs);
        };
        const getters = php.util.symbol.GetterExporter(T, .instance).get();
        const setters = php.util.symbol.SetterExporter(T, .instance).get();
        const methods = php.util.symbol.MethodExporter(T, .instance).get();
        const method_set = init: {
            const method_names = std.meta.fieldNames(@TypeOf(methods));
            var result: Object.MethodSet(method_names) = undefined;
            for (method_names) |method_name| {
                const method = @field(methods, method_name);
                @field(result.entries, method_name) = .init(method, .{
                    .self_source = .{ .this_object = T },
                });
            }
            break :init result;
        };
        const init_fn = init: {
            if (@hasDecl(T, "init")) {
                const Init = @TypeOf(T.init);
                const arg_count = php.util.argCount(Init);
                const Arg0 = switch (arg_count) {
                    0 => struct {},
                    1 => php.util.ArgType(Init, 0),
                    else => void,
                };
                if (@typeInfo(Arg0) != .@"struct") {
                    @compileError("init() should accept a single struct as its sole argument");
                }
                break :init .{ .exists = true, .Args = Arg0, .uses_args = arg_count > 0, .by_value = true };
            } else if (@hasDecl(T, "initSelf")) {
                const InitSelf = @TypeOf(T.initSelf);
                const arg_count = php.util.argCount(InitSelf);
                const Arg0 = switch (arg_count) {
                    1 => struct {},
                    2 => php.util.ArgType(InitSelf, 0),
                    else => void,
                };
                if (@typeInfo(Arg0) != .@"struct") {
                    @compileError("initSelf() should accept a single struct as its sole argument");
                }
                break :init .{ .exists = true, .Args = Arg0, .uses_args = arg_count > 1, .by_value = false };
            } else {
                // use setters to initialize custom struct
                const setter_names = std.meta.fieldNames(@TypeOf(setters));
                const len = setter_names.len;
                var field_names: [len][:0]const u8 = undefined;
                var field_types: [len]type = undefined;
                var field_attrs: [len]std.lang.Type.Struct.FieldAttributes = undefined;
                for (setter_names, 0..) |setter_name, i| {
                    const set = @field(setters, setter_name);
                    const Arg = php.util.ArgType(@TypeOf(set), 1);
                    field_names[i] = setter_name;
                    field_types[i] = switch (@typeInfo(Arg)) {
                        .optional => Arg,
                        else => ?Arg,
                    };
                    field_attrs[i] = .{};
                }
                const Args = @Struct(.auto, null, &field_names, &field_types, &field_attrs);
                break :init .{ .exists = false, .Args = Args };
            }
        };
        const deinit_fn = init: {
            if (@hasDecl(T, "deinit")) {
                const Deinit = @TypeOf(T.deinit);
                const arg_count = php.util.argCount(Deinit);
                const Arg0 = switch (arg_count) {
                    0 => void,
                    else => php.util.ArgType(Deinit, 0),
                };
                if (@typeInfo(Arg0) != .pointer or @typeInfo(Arg0).pointer.child != T) {
                    @compileError("deinit() should accept a self pointer");
                }
                if (arg_count > 1) {
                    @compileError("deinit() should accept no argument");
                }
                if (php.util.ReturnType(Deinit) != void) {
                    @compileError("deinit() should return void");
                }
                break :init .{ .exists = true };
            } else {
                break :init .{ .exists = false };
            }
        };
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
        const constructor = switch (@hasDecl(T, "getConstructor")) {
            true => {},
            false => Function.init(construct, .{
                .self_source = .{ .this_object = Object },
            }),
        };

        php_object: ObjectLite align(@max(@alignOf(ObjectLite), @alignOf(T))),
        custom_struct: T,
        flags: switch (@hasDecl(T, "getConstructor")) {
            true => void,
            false => packed struct { initialized: bool },
        },

        comptime {
            if (@offsetOf(@This(), "php_object") != 0) {
                @compileError("php_object is in the wrong position");
            }
        }
    };
}

pub const PropertyIterator = struct {
    pub fn init(array: *Array) @This() {
        return .{
            .array = array.retain(),
            .iter = array.iterate(.{}),
        };
    }

    pub fn deinit(self: *@This()) void {
        self.array.release();
    }

    pub fn next(self: *@This()) ?@Tuple(&.{ Value, Value }) {
        const value = self.iter.next() orelse return null;
        const key = self.iter.key();
        return .{ key, value };
    }

    pub fn reset(self: *@This()) void {
        self.iter.reset();
    }

    array: *Array,
    iter: Array.Iterator,
};
