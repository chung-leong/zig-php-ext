//! Data structure corresponding to a PHP enumeration.
const std = @import("std");

pub const Custom = @import("Enum/Custom.zig")._;
const php = @import("root.zig");
const c = php.c;
const Array = php.Array;
const Class = php.Class;
const Object = php.Object;
const pi = php.imports;
const String = php.String;
const Value = php.Value;

/// Return the class associated with the enumeration's class. Its cases are all instances of this
/// class.
pub fn class(self: *const @This()) *Class {
    return @constCast(&self.class_instance);
}
/// Create an enumeration and add it to the list of globally available classes.
///
/// `full_name` may contain a namespace. `kind` should be `.string`, `.integer`, or
/// `.@"undefined"`.
///
/// If an enumeration by that name already exists, `error.NameConflict` is returned.
pub fn register(comptime full_name: []const u8, kind: Value.Kind) !*@This() {
    var fn_entries = std.mem.zeroes([1]c.zend_function_entry);
    const cg = php.globals("compiler");
    const classes: *Array = @ptrCast(cg.class_table);
    if (classes.has(full_name)) return error.NameConflict;
    const zce = pi.zend_register_internal_enum(full_name.ptr, @backingInt(kind), &fn_entries);
    return @ptrCast(zce);
}
/// Obtain the object representing the case with the given name.
///
/// If no case by that name exists, `error.NotFound` is returned.
pub fn getCase(self: *@This(), name: *String) !*Object {
    const zobj = pi.zend_enum_get_case(@ptrCast(self.class()), @ptrCast(name));
    if (zobj == null) return error.NotFound;
    return @ptrCast(zobj);
}
/// Find a case by its value.
pub fn findCaseByValue(self: *@This(), value: Value) ?*Object {
    const cls = self.class();
    const table: *Array = @ptrCast(cls.impl.backed_enum_table);
    const name_value = table.get(value) catch return null;
    return self.getCase(name_value.string()) catch null;
}
/// Add a new case to the enumeration.
pub fn addCase(self: *@This(), name: *String, value: Value) void {
    var zval = value.toZval();
    pi.zend_enum_add_case(@ptrCast(self.class()), @ptrCast(name), &zval);
}

class_instance: Class,
