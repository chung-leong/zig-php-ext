const php = @import("../root.zig");
const Array = php.Array;
const c = php.c;
const Function = php.Function;
const Value = php.Value;
pub const Iterator = @import("Arguments/Iterator.zig");

pub fn obtain(self: *const @This()) struct {
    this: *const Value,
    regular: []Value,
    named: ?*Array,
} {
    var info: c.arg_extra_info = undefined;
    c.get_argument_info(@ptrCast(self), &info);
    return .{
        .this = @ptrCast(&self.impl.This),
        .regular = @ptrCast(info.ptr[0..info.len]),
        // extra_named_params contains bogus values when it's not used
        .named = if (info.extra) @ptrCast(self.impl.extra_named_params) else null,
    };
}

pub fn callee(self: *const @This()) *Function {
    return @ptrCast(self.impl.func);
}

pub fn iterate(self: *const @This()) Iterator {
    return .init(self);
}

impl: c.zend_execute_data,
