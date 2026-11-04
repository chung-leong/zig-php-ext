const std = @import("std");

pub const Custom = @import("Enumeration/Custom.zig").@"fn";
const php = @import("root.zig");
const c = php.c;
const Array = php.Array;
const Class = php.Class;
const Object = php.Object;
const pi = php.imports;
const String = php.String;
const Value = php.Value;

pub fn class(self: *const @This()) *Class {
    return @ptrCast(@constCast(self));
}

pub fn register(comptime full_name: []const u8, kind: Value.Kind) !*@This() {
    var fn_entries = std.mem.zeroes([1]c.zend_function_entry);
    const cg = php.globals("compiler");
    const classes: *Array = @ptrCast(cg.class_table);
    if (classes.has(full_name)) return error.NameConflict;
    const zce = pi.zend_register_internal_enum(full_name.ptr, @backingInt(kind), &fn_entries);
    return @ptrCast(zce);
}

pub fn getCase(self: *@This(), name: *String) *Object {
    const zobj = pi.zend_enum_get_case(@ptrCast(self.class()), @ptrCast(name));
    return @ptrCast(zobj);
}

pub fn findCaseByValue(self: *@This(), value: Value) ?*Object {
    const cls = self.class();
    const table: *Array = @ptrCast(cls.impl.backed_enum_table);
    const name_value = table.get(value) catch return null;
    return self.getCase(name_value.string());
}

pub fn addCase(self: *@This(), name: *String, value: Value) void {
    var zval = value.toZval();
    pi.zend_enum_add_case(@ptrCast(self.class()), @ptrCast(name), &zval);
}

class_entry: Class,
