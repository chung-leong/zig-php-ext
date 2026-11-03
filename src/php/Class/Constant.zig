const php = @import("../root.zig");
const c = php.c;
const Class = php.Class;
const php_al = php.allocator;
const String = php.String;
const Value = php.Value;

pub fn class(self: *const @This()) *Class {
    return @ptrCast(self.impl.ce);
}

pub fn value(self: *const @This()) Value {
    return .fromZval(self.impl.value);
}

pub fn register(comptime full_name: []const u8, const_value: Value, cls: *const Class) !*@This() {
    const self = create(cls, const_value);
    const constants = cls.constants();
    const constant_name: *String = .static(full_name);
    constants.set(constant_name, .fromPointer(self));
    return self;
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
