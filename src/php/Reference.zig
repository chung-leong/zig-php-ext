pub const std = @import("std");

const php = @import("root.zig");
const php_al = php.allocator;
const c = php.c;
const pi = php.imports;
const Value = php.Value;

pub fn create(value: Value) *@This() {
    const ref = php_al.create(Reference) catch unreachable;
    ref.* = .{
        .impl = .{
            .gc = .{ .refcount = 1, .u = .{ .type_info = c.GC_REFERENCE } },
            .val = value.toZval(),
            .sources = .{ .ptr = null },
        },
    };
    return ref;
}

pub fn retain(self: *@This()) *@This() {
    self.addRef();
    return self;
}

pub fn addRef(self: *@This()) void {
    self.impl.gc.refcount += 1;
}

pub fn release(self: *@This()) void {
    const zres = &self.impl;
    self.impl.gc.refcount -= 1;
    if (self.impl.gc.refcount == 0) {
        _ = pi.zend_reference_destroy(zres);
    }
}

pub fn subtractRef(self: *@This()) void {
    self.impl.gc.refcount -= 1;
}

pub fn target(self: *@This()) *Value {
    return @ptrCast(&self.impl.val);
}

const Reference = @This();

impl: c.zend_reference,
