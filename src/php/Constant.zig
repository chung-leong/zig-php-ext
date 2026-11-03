pub const AstRef = @import("Constant/AstRef.zig");
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

pub fn register(comptime full_name: []const u8, const_value: Value) !*@This() {
    // we can't use a static string here, since PHP insists on freeing it
    const const_name: *String = .create(full_name);
    const self = create(const_name, const_value);
    const constants = php.constants();
    if (constants.has(self.name())) return error.NameConflict;
    constants.set(const_name, .fromPointer(self));
    return self;
}

pub fn create(const_name: *String, const_value: Value) *@This() {
    const self = php_al.create(@This()) catch unreachable;
    self.* = .{
        .impl = .{
            .value = const_value.toZval(),
            .name = @ptrCast(const_name),
        },
    };
    self.impl.value.u2.constant_flags = c.CONST_PERSISTENT;
    return self;
}

impl: c.zend_constant,
