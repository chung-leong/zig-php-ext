//! Data structure corresponding to a variable reference in PHP.
const std = @import("std");

const php = @import("root.zig");
const php_al = php.allocator;
const c = php.c;
const pi = php.imports;
const Value = php.Value;

// Return a pointer to the reference's value.
pub fn target(self: *@This()) *Value {
    return @ptrCast(&self.impl.val);
}
/// Create a reference and initialize its value.
pub fn create(value: Value) *@This() {
    const ref = php_al.create(@This()) catch unreachable;
    ref.* = .{
        .impl = .{
            .gc = .{ .refcount = 1, .u = .{ .type_info = c.GC_REFERENCE } },
            .val = value.toZval(),
            .sources = .{ .ptr = null },
        },
    };
    return ref;
}
/// Increase the reference's refcount by one and return it.
pub fn retain(self: *@This()) *@This() {
    self.addRef();
    return self;
}
/// Increase the reference's refcount by one.
pub fn addRef(self: *@This()) void {
    self.impl.gc.refcount += 1;
}
/// Reduce the reference's refcount by one. When the refcount reaches zero, it's freed.
pub fn release(self: *@This()) void {
    const zres = &self.impl;
    self.impl.gc.refcount -= 1;
    if (self.impl.gc.refcount == 0) {
        _ = pi.zend_reference_destroy(zres);
    }
}
/// Reduce the reference's refcount by one.
pub fn subtractRef(self: *@This()) void {
    self.impl.gc.refcount -= 1;
}

impl: c.zend_reference,
