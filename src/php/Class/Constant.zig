const php = @import("../root.zig");
const c = php.c;
const Class = php.Class;
const php_al = php.allocator;
const pi = php.imports;
const Value = php.Value;

pub fn class(self: *const @This()) *Class {
    return @ptrCast(self.impl.ce);
}

pub fn value(self: *const @This()) Value {
    return .fromZval(self.impl.value);
}

pub fn create(cls: *const Class, const_value: Value) *@This() {
    const self = php_al.create(@This()) catch unreachable;
    self.* = .{
        .impl = .{
            .value = const_value.toZval(),
            .ce = @ptrCast(@constCast(cls)),
        },
    };
    self.impl.value.u2.constant_flags = c.CONST_PERSISTENT;
    return self;
}

impl: c.zend_class_constant,
