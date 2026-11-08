//! Data structure corresponding to a string in PHP.
const std = @import("std");

const php = @import("root.zig");
const c = php.c;
const deref = php.deref;
const pi = php.imports;
const php_al = php.allocator;
const unsupported = php.failure.unsupported;
const Value = php.Value;
pub const Allocator = @import("String/Allocator.zig");

/// Allocator for allocating memory for custom objects. Extra bytes are added in front of each
/// memory block so that fields for a PHP string can be added later:
pub const allocator: std.mem.Allocator = .{ .ptr = undefined, .vtable = &Allocator.vtable };
/// Return a slice pointer pointing the to string's contents.
pub fn slice(self: *const @This()) [:0]const u8 {
    const s: [*]const u8 = @ptrCast(&self.impl.val[0]);
    const len = self.impl.len;
    return @ptrCast(s[0..len]);
}
/// Return the string's byte length.
pub fn length(self: *const @This()) usize {
    return self.impl.len;
}
/// Return true if the string is interned (i.e. it's reused frequently).
pub fn isInterned(self: *const @This()) bool {
    return (self.impl.gc.u.type_info & c.IS_STR_INTERNED) != 0;
}
/// Return true if the string has to be duplicated before being modified.
pub fn isCopyOnWrite(self: *const @This()) bool {
    return self.impl.gc.refcount > 1 or self.isInterned();
}
/// Create a new string, using the given bytes as contents.
pub fn create(s: []const u8) *@This() {
    return switch (s.len) {
        0 => @ptrCast(deref(pi.zend_empty_string)),
        1 => @ptrCast(deref(pi.zend_one_char_string)[s[0]]),
        else => create: {
            const ns = createUninitialized(s.len);
            if (s.len > 0) {
                const new_slice = @constCast(ns.slice());
                @memcpy(new_slice, s);
            }
            break :create ns;
        },
    };
}
/// Create an uninitialized string.
pub fn createUninitialized(len: usize) *@This() {
    return switch (len) {
        0 => @ptrCast(deref(pi.zend_empty_string)),
        else => create: {
            const struct_size = @offsetOf(c.zend_string, "val") + len + 1;
            const aligned_size = std.mem.alignForward(usize, struct_size, c.ZEND_MM_ALIGNMENT);
            const bytes = php_al.alloc(u8, aligned_size) catch unreachable;
            const zs: *c.zend_string = @ptrCast(@alignCast(bytes.ptr));
            var type_info: u32 = c.GC_STRING;
            if (php.Allocator.mode == .persistent) type_info |= c.IS_STR_PERSISTENT;
            zs.* = .{
                .gc = .{ .refcount = 1, .u = .{ .type_info = type_info } },
                .h = 0,
                .len = len,
            };
            // set sentinel
            bytes[struct_size - 1] = 0;
            break :create @ptrCast(zs);
        },
    };
}
/// Create an interned string.
pub fn createInterned(s: []const u8) *@This() {
    const zend_string_init_interned = deref(pi.zend_string_init_interned);
    const zstr = zend_string_init_interned.?(s.ptr, s.len, false);
    return @ptrCast(zstr);
}
/// Create a new string using the given
pub fn createFromAny(arg: anytype) *@This() {
    const AT = @TypeOf(arg);
    return switch (@typeInfo(AT)) {
        .pointer => |pt| switch (pt.child) {
            @This() => arg.retain(),
            u8 => switch (pt.size) {
                .slice => create(arg),
                .c, .many => create(std.mem.sliceTo(arg, 0)),
                else => unsupported(AT),
            },
            else => switch (@typeInfo(pt.child)) {
                .array => |ar| switch (ar.child) {
                    u8 => create(arg),
                    else => unsupported(AT),
                },
                else => unsupported(AT),
            },
        },
        .@"struct" => switch (AT) {
            Value => arg.stringify().string(),
        },
        else => unsupported(AT),
    };
}
/// Render a formatted string using `std.mem.Allocator.printSentinel` and turn it into a PHP
/// string.
pub fn print(comptime fmt: []const u8, args: anytype) *@This() {
    const offset = @offsetOf(c.zend_string, "val");
    const offset_bytes = comptime init: {
        var bytes: [offset]u8 = undefined;
        for (&bytes) |*ptr| ptr.* = ' ';
        break :init bytes;
    };
    const bytes = php_al.printSentinel(offset_bytes ++ fmt, args, 0) catch unreachable;
    const zs: *c.zend_string = @ptrCast(@alignCast(bytes.ptr));
    var type_info: u32 = c.GC_STRING;
    if (php.Allocator.mode == .persistent) type_info |= c.IS_STR_PERSISTENT;
    zs.gc = .{ .refcount = 1, .u = .{ .type_info = type_info } };
    zs.h = 0;
    zs.len = @intCast(bytes.len - offset);
    return @ptrCast(zs);
}
/// Increase the string's refcount by one and return the string.
pub fn retain(self: *@This()) *@This() {
    self.addRef();
    return self;
}
/// Increase the string's refcount by one.
pub fn addRef(self: *@This()) void {
    self.impl.gc.refcount += 1;
}
/// Reduce the string's refcount by one. If the refcount has reached zero, the string is freed.
pub fn release(self: *@This()) void {
    const zstr = &self.impl;
    pi.zend_string_release(zstr);
}
/// Reduce the string's refcount by one
pub fn subtractRef(self: *@This()) void {
    self.impl.gc.refcount -= 1;
}
/// See if the string matches another string.
pub fn match(self: *const @This(), s2: *const @This()) bool {
    if (self.impl.h != 0 and s2.impl.h != 0) {
        if (self.impl.h != s2.impl.h) return false;
    }
    return self.matchSlice(s2.slice());
}
/// See if the string contains the same contents as the given slice.
pub fn matchSlice(self: *const @This(), s2: []const u8) bool {
    return std.mem.eql(u8, self.slice(), s2);
}
/// See if the string matches a comptime-known string. A negative result can established very
/// quickly thanks to the comptime-calculated hash.
pub fn matchStatic(self: *const @This(), comptime s2: []const u8) bool {
    const h2 = comptime calculateHash(s2);
    if (self.impl.h != 0 and self.impl.h != h2) return false;
    return std.mem.eql(u8, self.slice(), s2);
}
/// Create a copy of the string.
pub fn duplicate(self: *const @This()) *@This() {
    return .create(self.slice());
}
/// Create a low-case version of the string.
pub fn duplicateLowerCase(self: *const @This()) *@This() {
    const dup: *@This() = .create(self.slice());
    const s = @constCast(dup.slice());
    pi.zend_str_tolower(s.ptr, s.len);
    return dup;
}
/// Place the string in a `Value`.
pub fn toValue(self: *const @This()) Value {
    return .fromString(self);
}
/// Extract either an integer or floating-point nuimber from a string.
pub fn toNumeric(self: *const @This()) !union(enum) {
    integer: php.Long,
    float: f64,
} {
    const s = self.slice();
    var long: php.Long = undefined;
    var double: f64 = undefined;
    const result = if (s[0] > '9')
        c.IS_UNDEF
    else
        pi._is_numeric_string_ex(s.ptr, s.len, &long, &double, false, null, null);
    return switch (result) {
        c.IS_LONG => .{ .integer = long },
        c.IS_DOUBLE => .{ .float = double },
        else => error.NotNumeric,
    };
}
/// Obtain a boolean from a string, based on rules governing in php.ini. "On" and "Yes" are
/// interpreted as true while "Off" and "No" mean false.
pub fn parseBoolean(self: *const @This()) bool {
    const zstr = @constCast(&self.impl);
    return pi.zend_ini_parse_bool(zstr);
}
/// Convert a string to an integer.
pub fn parseInteger(self: *const @This()) php.Long {
    const s = self.slice();
    return pi.zend_atol(s.ptr, s.len);
}
/// Convert a string to a floating-point number.
pub fn parseFloat(self: *const @This()) f64 {
    const s = self.slice();
    return pi.zend_strtod(s.ptr, null);
}
/// Obtain a string from a slice pointer, based on the assumption that there're extra valid bytes
/// in front of the slice.
///
/// `s` should be pointer returned previously by `String.allocator.alloc`.
pub fn fromOwnSlice(s: []const u8) *@This() {
    if (s.len == 0) return create(s);
    const field_ptr: *@FieldType(c.zend_string, "val") = @ptrCast(@constCast(s.ptr));
    const zstr: *c.zend_string = @alignCast(@fieldParentPtr("val", field_ptr));
    if (zstr.len != s.len) {
        // more memory was allocated than used by the slice
        zstr.len = s.len;
        const ptr: [*]u8 = @ptrCast(&zstr.val);
        ptr[s.len] = 0;
    }
    return @ptrCast(zstr);
}
/// Function used in comptime to create a static string.
pub fn static(comptime s: []const u8) *@This() {
    const ns = struct {
        // need to use var since PHP will try to set additional flags
        var str: StringWithLength(s.len) = .{
            .gc = .{
                .refcount = 0,
                .u = .{
                    .type_info = c.IS_STRING | c.IS_STR_PERMANENT | c.IS_STR_INTERNED | c.GC_NOT_COLLECTABLE,
                },
            },
            .h = calculateHash(s),
            .val = init: {
                const len = s.len;
                var buf: [len + 1]u8 = undefined;
                @memcpy(buf[0..len], s);
                buf[len] = 0;
                break :init buf;
            },
        };
    };
    return @ptrCast(@constCast(&ns.str));
}
/// Calculate the string hash of the given bytes.
pub fn calculateHash(s: []const u8) c.zend_ulong {
    if (@inComptime()) {
        // we can't use the function from PHP at comptime because it uses memcpy() when the target is ARM64
        var hash: c.zend_ulong = 5381;
        for (s) |char| hash = hash *% 33 +% char;
        hash |= switch (@sizeOf(c.zend_ulong)) {
            8 => 0x8000000000000000,
            4 => 0x80000000,
            else => unreachable,
        };
        return hash;
    } else {
        return pi.zend_inline_hash_func(s.ptr, s.len);
    }
}

fn StringWithLength(comptime len: usize) type {
    return extern struct {
        gc: c.zend_refcounted_h = undefined,
        h: c.zend_ulong = undefined,
        len: usize = len,
        val: [len + 1]u8 = undefined,
    };
}

impl: c.zend_string,
