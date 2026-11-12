//! Data structure corresponding to an array in PHP.
const std = @import("std");

pub const Iterator = @import("./Array/Iterator.zig");
const php = @import("root.zig");
const Allocator = php.Allocator;
const c = php.c;
const php_al = php.allocator;
const pi = php.imports;
const String = php.String;
const unsupported = php.failure.unsupported;
const Value = php.Value;

/// Return the number of elements currently held by the array.
pub fn length(self: *const @This()) usize {
    const arr = &self.impl;
    return arr.nNumOfElements;
}
/// Return the numeric index of the next item to be inserted.
pub fn nextIndex(self: *const @This()) isize {
    const arr = &self.impl;
    return switch (arr.nNextFreeElement) {
        std.math.minInt(@TypeOf(arr.nNextFreeElement)) => 0,
        else => |i| i,
    };
}
/// Return true if the array's keys are sequential and start at zero.
pub fn isZeroBased(self: *const @This()) bool {
    return self.nextIndex() == self.length();
}
/// Return true if all the array's keys are strings.
pub fn isAssociative(self: *const @This()) bool {
    const arr = &self.impl;
    if (arr.u.flags & c.HASH_FLAG_PACKED != 0) return false;
    return for (0..arr.nNumUsed) |i| {
        const p = switch (@hasField(c.zend_array, "arData")) {
            // in newer version of PHP, the field is stored in an unnamed union
            false => arr.unnamed_0.arData[i],
            true => arr.arData[i],
        };
        if (p.val.u1.v.type != c.IS_UNDEF and p.key == null) break false;
    } else true;
}
/// Create an empty array.
pub fn create() *@This() {
    const arr = pi._zend_new_array_0();
    return @ptrCast(arr);
}
/// Create an empty array with the specified destructor attached instead of the standard one for `Value`.
pub fn createWithDestructor(dtor: c.dtor_func_t) *@This() {
    const alignment: std.mem.Alignment = .fromByteUnits(@alignOf(c.zend_array));
    const byte_ptr = php_al.rawAlloc(@sizeOf(c.zend_array), alignment, @returnAddress());
    const arr: *c.zend_array = @ptrCast(@alignCast(byte_ptr));
    pi._zend_hash_init(arr, c.HT_MIN_SIZE, dtor, Allocator.mode == .persistent);
    return @ptrCast(arr);
}
/// Create an empty array, with a length hint suggesting the eventual memory usage.
pub fn createWithLength(len: usize) *@This() {
    const arr = pi._zend_new_array(@intCast(len));
    return @ptrCast(arr);
}
/// Create an array and populated it using the given argument.
///
/// `arg` can be a array, a slice pointer, a vector, or a struct.
pub fn createFromAny(arg: anytype, options: Value.ConversionOptions) *@This() {
    const T = @TypeOf(arg);
    const supported = switch (@typeInfo(T)) {
        .array, .vector, .@"struct" => true,
        .pointer => |pt| pt.size == .slice,
        else => false,
    };
    if (!supported) @compileError("Array, slice, vector, or struct expected, received: " ++ @typeName(T));
    const arr = create();
    switch (@typeInfo(T)) {
        .vector => |ve| {
            // vectors require an unrolled loop
            inline for (0..ve.len) |i| arr.append(.createFromAny(arg[i], options));
        },
        .@"struct" => |st| if (st.is_tuple) {
            inline for (arg) |item| {
                const value: Value = .createFromAny(item, options);
                defer value.release();
                arr.append(value);
            }
        } else {
            inline for (st.field_names) |field_name| {
                const item = @field(arg, field_name);
                const key = String.static(field_name);
                const value: Value = .createFromAny(item, options);
                defer value.release();
                arr.set(key, value);
            }
        },
        else => {
            for (arg) |item| {
                const value: Value = .createFromAny(item, options);
                defer value.release();
                arr.append(value);
            }
        },
    }
    return arr;
}
/// Increase the array's refcount and return it.
pub fn retain(self: *@This()) *@This() {
    self.addRef();
    return self;
}
/// Reduce the array's refcount by one and return it.
pub fn cede(self: *@This()) *@This() {
    self.impl.gc.refcount -= 1;
    return self;
}
/// Increase the array's refcount by one.
pub fn addRef(self: *@This()) void {
    self.impl.gc.refcount += 1;
}
/// Reduce the array's refcount by one. Free the array and its contents if the refcount has reached zero.
pub fn release(self: *@This()) void {
    const arr = &self.impl;
    pi.zend_hash_release(arr);
}
/// Check whether the array contains an element with the given key.
///
/// `key` can be an integer, `[]const u8`, or `String`.
pub fn has(self: *const @This(), key: anytype) bool {
    return if (self.getPointer(key)) |_| true else |_| false;
}
/// Find an element by key.
///
/// `key` can be an integer, `[]const u8`, or `String`.
///
/// If there is no element matching the given key, `error.Missing` is returned.
pub fn get(self: *const @This(), key: anytype) !Value {
    const ptr = try self.getPointer(key);
    return ptr.*;
}
/// Return a pointer to an array element. This pointer can be used to modify the element directly.
///
/// `key` can be an integer, `[]const u8`, or `String`.
///
/// If there is no element matching the given key, `error.Missing` is returned.
pub fn getPointer(self: *const @This(), key: anytype) !*Value {
    const arr = &self.impl;
    const zval = switch (Key.fromAny(key)) {
        .integer => |i| pi.zend_hash_index_find(arr, i),
        .string => |str| pi.zend_hash_find(arr, @ptrCast(str)),
        .slice => |slice| pi.zend_hash_str_find(arr, slice.ptr, slice.len),
    } orelse return error.Missing;
    return @ptrCast(zval);
}
/// Add an element to the element at given key. Is the slot is already occupied by another value,
/// that value is replaced. If it contains an object, that object is released.
///
/// `key` can be an integer, `[]const u8`, or `String`.
pub fn set(self: *@This(), key: anytype, value: Value) void {
    const arr = &self.impl;
    const zval: *c.zval = @ptrCast(@constCast(&value));
    _ = switch (Key.fromAny(key)) {
        .integer => |i| pi.zend_hash_index_update(arr, i, zval),
        .string => |str| pi.zend_hash_update(arr, @ptrCast(str), zval),
        .slice => |slice| pi.zend_hash_str_update(arr, slice.ptr, slice.len, zval),
    };
    value.addRef();
}
/// Remove an element, not indicating whether the operation was successful.
pub fn delete(self: *@This(), key: anytype) void {
    _ = self.remove(key);
}
/// Remove an element, returning if successful.
///
/// `key` can be an integer, `[]const u8`, or `String`.
pub fn remove(self: *@This(), key: anytype) bool {
    const arr = &self.impl;
    const result = switch (Key.fromAny(key)) {
        .integer => |i| pi.zend_hash_index_del(arr, i),
        .string => |str| pi.zend_hash_del(arr, @ptrCast(str)),
        .slice => |slice| pi.zend_hash_str_del(arr, slice.ptr, slice.len),
    };
    return result == c.SUCCESS;
}
/// Append an element at the end of the array.
pub fn append(self: *@This(), value: Value) void {
    const arr = &self.impl;
    arr.*.u.flags |= c.HASH_FLAG_ALLOW_COW_VIOLATION;
    _ = pi.zend_hash_next_index_insert(arr, @ptrCast(@constCast(&value)));
    value.addRef();
}
/// Create an iterator for traversing the array, either forward or backward.
pub fn iterate(self: *const @This(), options: Iterator.Options) Iterator {
    return .init(self, options);
}
/// Place the array into a `Value`.
pub fn toValue(self: *const @This()) Value {
    return .fromArray(self);
}

const Key = union(enum) {
    pub fn fromAny(arg: anytype) @This() {
        const KT = @TypeOf(arg);
        return switch (@typeInfo(KT)) {
            .int => |int| switch (int.signedness) {
                .signed => .{ .integer = @as(c.zend_ulong, @bitCast(arg)) },
                .unsigned => .{ .integer = arg },
            },
            .comptime_int => .{ .integer = arg },
            .pointer => |pt| switch (pt.child) {
                String => .{ .string = @constCast(arg) },
                u8 => switch (pt.size) {
                    .slice => .{ .slice = arg },
                    .c, .many => .{ .slice = std.mem.sliceTo(arg, 0) },
                    else => unsupported(KT),
                },
                else => switch (@typeInfo(pt.child)) {
                    .array => |ar| switch (ar.child) {
                        u8 => .{ .slice = arg },
                        else => unsupported(KT),
                    },
                    else => unsupported(KT),
                },
            },
            .@"struct" => switch (KT) {
                Value => switch (arg.kind()) {
                    .string => fromAny(arg.string()),
                    .integer => fromAny(arg.integer()),
                    else => @panic("Unexpected"),
                },
                else => unsupported(KT),
            },
            else => unsupported(KT),
        };
    }

    integer: c.zend_ulong,
    string: *String,
    slice: []const u8,
};
const Array = @This();

impl: c.zend_array,
