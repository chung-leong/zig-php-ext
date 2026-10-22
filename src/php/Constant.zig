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

pub fn create(const_name: []const u8, arg: anytype) *@This() {
    const self = php_al.create(@This()) catch unreachable;
    const name_str: *String = .create(const_name);
    var v: Value = .fromAny(arg);
    v.impl.u2.constant_flags = c.CONST_PERSISTENT;
    self.* = .{
        .impl = .{
            .name = @ptrCast(name_str),
            .value = v.toZval(),
        },
    };
    return self;
}

pub fn register(self: *const @This(), arr: *Array) !void {
    if (arr.has(self.name())) return error.NameConflict;
    arr.set(self.name(), .fromPointer(self));
}

impl: c.zend_constant,
