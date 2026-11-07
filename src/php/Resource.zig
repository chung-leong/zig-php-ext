//! Data structure corresponding to a resource in PHP.
const php = @import("root.zig");
const c = php.c;
const pi = php.imports;

/// Increase the resource's refcount by one and return it.
pub fn retain(self: *@This()) *@This() {
    self.addRef();
    return self;
}
/// Increase the resource's refcount by one.
pub fn addRef(self: *@This()) void {
    self.impl.gc.refcount += 1;
}
/// Reduce the resource's refcount by one. When the refcount reaches zero, it's freed.
pub fn release(self: *@This()) void {
    const zres = &self.impl;
    _ = pi.zend_list_delete(zres);
}
/// Reduce the resource's refcount by one.
pub fn subtractRef(self: *@This()) void {
    self.impl.gc.refcount -= 1;
}

impl: c.zend_resource,
