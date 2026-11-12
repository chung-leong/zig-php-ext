//! Data structure corresponding to an object in PHP.
const std = @import("std");
const builtin = @import("builtin");

pub const Allocator = @import("Object/Allocator.zig");
pub const Custom = @import("Object/Custom.zig")._;
pub const Iterator = @import("Object/Iterator.zig");
pub const MethodSet = @import("Object/MethodSet.zig")._;
pub const Opcode = @import("Object/Opcode.zig")._;
pub const StdClass = @import("Object/StdClass.zig");
const php = @import("root.zig");
const Array = php.Array;
const c = php.c;
const pi = php.imports;
const deref = php.deref;
const Class = php.Class;
const failure = php.failure;
const unsupported = failure.unsupported;
const Function = php.Function;
const String = php.String;
const Value = php.Value;
/// Struct containing handlers.
pub const Handlers = c.zend_object_handlers;

/// Allocator for allocating memory for custom objects. Extra bytes are added in front of each
/// memory block so that a PHP object wrapper can be added later:
///
/// [ extra bytes ][ bytes returned to caller ]
///
/// Initially, the extra bytes contain all zeroes. If they are still zeroes when `free` is called,
/// the allocator frees the memory in the normal manner. If a PHP object has been created around
/// the data, that object is released.
pub const allocator: std.mem.Allocator = .{ .ptr = undefined, .vtable = &Allocator.vtable };
/// Return the `Class` of each the object is an instance.
pub fn class(self: *const @This()) *const Class {
    return @ptrCast(self.impl.ce);
}
/// Return the object's internal handle.
pub fn handle(self: *const @This()) php.Long {
    return @ptrCast(self.impl.handle);
}
/// Return the object's dynamic properties. Only relevant when the object is an instance of
/// stdclass.
pub fn properties(self: *const @This()) *Array {
    return @ptrCast(self.impl.properties);
}
/// Create an instance of the given class and invoke its constructor.
pub fn create(cls: *const Class, params: []const Value) !*@This() {
    const zobj = pi.zend_objects_new(@ptrCast(@constCast(cls)));
    const handlers = zobj.*.handlers;
    const handler = handlers.*.get_constructor;
    const ctor = handler.?(zobj);
    if (ctor) |f| {
        const zparams: [*]c.zval = @ptrCast(@constCast(params.ptr));
        const len: u32 = @truncate(params.len);
        switch (@hasDecl(c, "zend_call_known_function_ex")) {
            true => pi.zend_call_known_function_ex(f, zobj, zobj.*.ce, null, len, zparams, null, 0),
            false => pi.zend_call_known_function(f, zobj, zobj.*.ce, null, len, zparams, null),
        }
    }
    return @ptrCast(zobj);
}
/// Create a standard object (stdclass).
pub fn createStandard() *@This() {
    const ce = Class.builtin(.standard);
    const zobj = pi.zend_objects_new(@ptrCast(@constCast(ce)));
    return @ptrCast(zobj);
}
/// Create an instance of a class defined using `Class.Custom` and copy `initializers` into the
/// custom portion.
///
/// If `Class.Custom(T)` has not been exported, a panic would occur.
pub fn createCustom(comptime T: type, initializers: T) *@This() {
    // when T fails validation the Object.Custom(T) yields an empty struct
    const custom_obj = Object.Custom(T).create();
    custom_obj.custom().* = initializers;
    custom_obj.flags.initialized = true;
    return custom_obj.object();
}
/// Look up a class by name and create an instance of it.
///
/// `name` can be `[]const u8` or `String`.
pub fn createFromName(name: anytype, params: []const Value) !*@This() {
    const cls = Class.find(name) orelse return error.ClassNotFound;
    return .create(cls, params);
}
/// Create a standard object and attach the given array to it as its properties.
pub fn createFromArray(arr: *Array) *@This() {
    const obj: Object = .createStandard();
    obj.properties = arr;
    return obj;
}
/// Increase the object's refcount by one and return the object.
pub fn retain(self: *@This()) *@This() {
    self.addRef();
    return self;
}
/// Reduce the object's refcount by one and return the object.
pub fn cede(self: *@This()) *@This() {
    self.impl.gc.refcount -= 1;
    return self;
}
/// Increase the object's refcount by one.
pub fn addRef(self: *@This()) void {
    self.impl.gc.refcount += 1;
}
/// Reduce the array's refcount by one. Free the object if the refcount has reached zero.
pub fn release(self: *@This()) void {
    const zobj = &self.impl;
    pi.zend_object_release(zobj);
}
/// Place the object into a `Value`.
pub fn toValue(self: *const @This()) Value {
    return .fromObject(self);
}
/// Return true if the given object does not actually exist.
pub fn isUninitialized(self: *const @This()) bool {
    return self.impl.handlers == null;
}
/// Check if the object is an instance of the given class.
pub fn isInstanceOf(self: *const @This(), cls: *const Class) bool {
    const zobj = &self.impl;
    const zce: *const c.zend_class_entry = @ptrCast(cls);
    return (zobj.ce == zce) or pi.instanceof_function_slow(zobj.ce, zce);
}
/// Check if the object implements a given interface.
pub fn hasInterface(self: *const @This(), iface: Class.InterfaceId) bool {
    return self.isInstanceOf(iface.get());
}
/// Check if an array-like object contains an element at the given key.
pub fn hasDimension(self: *const @This(), key: anytype) !bool {
    const zobj = @constCast(&self.impl);
    const k: Value = .createFromAny(key);
    defer k.release();
    const std_handlers = standardHandlers();
    const handler = zobj.handlers.*.has_dimension orelse return error.NoArrayAccess;
    if (@hasField(c.zend_class_entry, "arrayaccess_funcs_ptr")) {
        if (zobj.ce.*.arrayaccess_funcs_ptr == null) {
            if (std_handlers.has_dimension == handler) return error.NoArrayAccess;
        }
    }
    const zk: *c.zval = @ptrCast(@constCast(&k.value));
    const rv = handler(zobj, zk, false);
    return rv != null;
}
/// Obtain an element from an array-like object.
///
/// `key` can be an integer, `[]const u8`, or `String`.
///
/// If there is no element matching the given key, `error.Missing` is returned.
/// `error.NoArrayAccess` is return when the object is not array-like.
pub fn readDimension(self: *const @This(), key: anytype) !Value {
    const zobj = @constCast(&self.impl);
    const k: Key = .createFromAny(key);
    defer k.release();
    var value: Value = undefined;
    const zval: *c.zval = @ptrCast(&value);
    const std_handlers = standardHandlers();
    const handler = zobj.handlers.*.read_dimension orelse return error.NoArrayAccess;
    if (@hasField(c.zend_class_entry, "arrayaccess_funcs_ptr")) {
        if (zobj.ce.*.arrayaccess_funcs_ptr == null) {
            if (std_handlers.read_dimension == handler) return error.NoArrayAccess;
        }
    }
    const zk: *c.zval = @ptrCast(@constCast(&k.value));
    const rv = handler(zobj, zk, c.BP_VAR_R, zval);
    if (rv == null) return error.Missing;
    return @as(*Value, @ptrCast(rv)).*;
}
/// Obtain the element count from an array-like object.
///
/// If the object is unable to provide a length `error.NotKnowable` is returned.
pub fn countElements(self: *const @This()) !usize {
    const zobj = @constCast(&self.impl);
    const handler = zobj.handlers.*.count_elements orelse return error.NoArrayAccess;
    var count: c.zend_long = undefined;
    const result = handler(zobj, &count);
    if (result != c.SUCCESS) return error.NotKnowable;
    return @intCast(count);
}
/// Obtain a property of the object.
///
/// If the object does not have a property by that name, `error.Missing` is returned.
pub fn readProperty(self: *const @This(), name: anytype) !Value {
    const zobj = @constCast(&self.impl);
    const n: *String = .createFromAny(name);
    defer n.release();
    var value: Value = undefined;
    const zval: *c.zval = @ptrCast(&value);
    const zn: *c.zend_string = @ptrCast(n);
    const handler = zobj.handlers.*.read_property orelse return error.NoPropertyAccess;
    const access: Value.Access = .read;
    const result = handler(zobj, zn, @backingInt(access), null, zval);
    if (result == null) return error.Missing;
    return .fromZval(result.*);
}
/// Check if the object has a property by the given name.
pub fn hasProperty(self: *const @This(), name: anytype) !bool {
    const zobj = @constCast(&self.impl);
    const n: *String = .createFromAny(name);
    defer n.release();
    const zn: *c.zend_string = @ptrCast(n);
    const handler = zobj.handlers.*.has_property orelse return error.NoPropertyAccess;
    const state: Value.State = .present;
    const result = handler(zobj, zn, @backingInt(state), null);
    return result != 0;
}
/// Return all properties of the object in an array.
pub fn getProperties(self: *const @This()) *Array {
    var value = self.toValue();
    const zval: *c.zval = @ptrCast(&value);
    const ht = pi.zend_get_properties_for(zval, c.ZEND_PROP_PURPOSE_ARRAY_CAST).?;
    return @ptrCast(ht);
}
/// Return true if the object is an instance of a custom class.
pub fn isCustom(self: *const @This(), comptime T: type) bool {
    return @intFromPtr(self.impl.handlers) == @intFromPtr(&Custom(T).handlers);
}
/// Return a pointer to the custom portion of a custom object.
///
/// A custom object contains a PHP portion and a custom portion. The PHP portion, holding
/// internal fields used by the Zend Engine, sits at the beginning of the memory block. The
/// custom portion (i.e. `T`) follows:
///
/// [ PHP portion ][ custom portion ]
///
/// This function simply shifts `self` pointer forward by a certain number of bytes.
pub fn custom(self: *const @This(), comptime T: type) *T {
    const custom_obj: *Custom(T) = @ptrCast(@constCast(self));
    return custom_obj.custom();
}
/// Return a pointer to `Object` given a pointer to the custom portion of a custom object.
///
/// This function is the inverse of `custom`.
pub fn fromCustom(custom_ptr: anytype) *@This() {
    const T = @TypeOf(custom_ptr.*);
    const custom_obj = Custom(T).fromCustom(custom_ptr);
    const self = custom_obj.object();
    if (self.isUninitialized()) {
        // set class, handlers, etc. and register object with PHP
        custom_obj.initPhpPortion();
        self.impl.gc.refcount = 0;
    } else if (builtin.mode == .debug and !self.isCustom(T)) {
        @panic("pointer to " ++ @typeName(T) ++ " not within a proper object");
    }
    return self;
}
/// Return the object handlers used by instances of `stdclass`.
pub fn standardHandlers() *const Handlers {
    return deref(&pi.std_object_handlers);
}
/// Utility function for creating property getters for a custom object
pub fn getter(comptime T: type, comptime field: std.meta.FieldEnum(T)) RT: {
    const field_name = @tagName(field);
    const FT = @FieldType(T, field_name);
    break :RT fn (*const T) FT;
} {
    const field_name = @tagName(field);
    const FT = @FieldType(T, field_name);
    const ns = struct {
        fn _(self: *const T) FT {
            return @field(self, field_name);
        }
    };
    return ns._;
}
/// Utility function for creating property setters for a custom object
pub fn setter(comptime T: type, comptime field: std.meta.FieldEnum(T)) RT: {
    const field_name = @tagName(field);
    const FT = @FieldType(T, field_name);
    break :RT fn (*T, FT) void;
} {
    const field_name = @tagName(field);
    const FT = @FieldType(T, field_name);
    const ns = struct {
        fn _(self: *T, value: FT) void {
            if (comptime php.util.hasPointer(FT)) {
                if (!php.util.fieldHasDefaultValue(self, field_name)) {
                    php.util.freeAny(@field(self, field_name));
                }
                @field(self, field_name) = php.util.retainAny(value, .{ .duplicate_slice = false });
            } else {
                @field(self, field_name) = value;
            }
        }
    };
    return ns._;
}
/// Struct returned by the `getGarbageCollection` handler.
pub const GarbageCollectionResult = struct {
    slice: []const *Value = &.{},
    array: ?*Array = null,
};
/// Struct returned by the `gteClosure` handler.
pub const ClosureResult = struct {
    class: ?*const Class = null,
    function: ?*const Function = null,
    object: ?*const Object = null,
};
/// Purpose of the data to be returned by the `getProperties` handler
pub const PropertiesPurpose = enum(c_int) {
    /// Used for debugging. Supersedes get_debug_info handler.
    debug = c.ZEND_PROP_PURPOSE_DEBUG,
    /// Used for (array) casts.
    array = c.ZEND_PROP_PURPOSE_ARRAY_CAST,
    /// Used for serialization using the "O" scheme.
    /// Unserialization will use __wakeup().
    serialize = c.ZEND_PROP_PURPOSE_SERIALIZE,
    /// Used for var_export().
    /// The data will be passed to __set_state() when evaluated.
    var_export = c.ZEND_PROP_PURPOSE_VAR_EXPORT,
    /// Used for json_encode().
    json = c.ZEND_PROP_PURPOSE_JSON,
    /// Used for get_object_vars().
    get_object_vars = switch (@hasDecl(c, "ZEND_PROP_PURPOSE_GET_OBJECT_VARS")) {
        true => c.ZEND_PROP_PURPOSE_GET_OBJECT_VARS,
        false => c.ZEND_PROP_PURPOSE_JSON + 1,
    },
    default,
};

const Key = struct {
    pub fn createFromAny(arg: anytype) @This() {
        const AT = @TypeOf(arg);
        return switch (@typeInfo(AT)) {
            .int, .comptime_int => .{ .value = .fromInteger(@intCast(arg)) },
            else => .{ .value = .fromString(.createFromAny(arg)) },
        };
    }

    pub fn release(self: @This()) void {
        self.value.release();
    }

    value: Value,
};
const Object = @This();

impl: c.zend_object,
