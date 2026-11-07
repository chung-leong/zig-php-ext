const std = @import("std");

const php = @import("root.zig");
const c = php.c;
const failure = php.failure;
const unsupported = failure.unsupported;
const Object = php.Object;
const pi = php.imports;
const Singleton = php.Singleton;
const String = php.String;
const Value = php.Value;
const errable = php.util.errable;

/// Different kind of ini entries, applicable to setters.
pub const Kind = enum(u8) {
    user = c.ZEND_INI_USER,
    per_dir = c.ZEND_INI_PERDIR,
    system = c.ZEND_INI_SYSTEM,
    all = c.ZEND_INI_ALL,
};
/// Utility function for creating property getters for a custom module.
pub fn getter(comptime T: type, comptime field: std.meta.FieldEnum(T)) RT: {
    const field_name = @tagName(field);
    const FT = @FieldType(T, field_name);
    break :RT fn (*const T) FT;
} {
    const field_name = @tagName(field);
    const FT = @FieldType(T, field_name);
    const ns = struct {
        fn _(self: *const T) FT {
            return @field(self, field_name);
        }
    };
    return ns._;
}
/// Utility function for creating property setters for a custom module.
pub fn setter(comptime T: type, field: std.meta.FieldEnum(T)) RT: {
    const field_name = @tagName(field);
    const FT = @FieldType(T, field_name);
    break :RT fn (*T, FT) void;
} {
    const field_name = @tagName(field);
    const FT = @FieldType(T, field_name);
    const ns = struct {
        fn _(self: *T, value: FT) void {
            // don't need to duplicate strings, since PHP retains them
            @field(self, field_name) = value;
        }
    };
    return ns._;
}

impl: c.zend_ini_entry,
