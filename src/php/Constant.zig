pub const std = @import("std");

const php = @import("root.zig");
const c = php.c;
const php_al = php.allocator;
const pi = php.imports;
const Array = php.Array;
const String = php.String;
const Value = php.Value;

pub fn name(self: *const @This()) *String {
    return @ptrCast(self.impl.name);
}

pub fn value(self: *const @This()) Value {
    return .fromZval(self.impl.value);
}

pub fn find(n: *String) ?*@This() {
    const eg = php.globals("executor");
    const list: *Array = @ptrCast(eg.zend_constants);
    const v = list.get(n) catch return null;
    return v.getPointerOf(@This()) catch return null;
}

pub fn fromAny(n: *String, arg: anytype) @This() {
    var v: Value = .fromAny(arg);
    v.impl.u2.constant_flags = c.CONST_PERSISTENT;
    return .{
        .impl = .{
            .name = @ptrCast(n),
            .value = v.toZval(),
        },
    };
}

pub fn register(self: *const @This()) !void {
    const eg = php.globals("executor");
    const list: *Array = @ptrCast(eg.zend_constants);
    if (list.has(self.name())) return error.NameConflict;
    const copy = try php_al.create(@This());
    copy.* = self.*;
    list.set(self.name(), .fromPointer(copy));
}

pub fn unregister(self: *const @This()) void {
    const eg = php.globals("executor");
    const list: *Array = @ptrCast(eg.zend_constants);
    list.delete(self.name());
}

impl: c.zend_constant,
