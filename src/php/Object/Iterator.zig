const php = @import("../root.zig");
const Array = php.Array;
const c = php.c;
const php_al = php.allocator;
const pi = php.imports;
const Value = php.Value;
pub const Functions = c.zend_object_iterator_funcs;
pub const Custom = @import("Iterator/Custom.zig").@"fn";

pub fn init(functions: *const Functions) @This() {
    var self: @This() = undefined;
    pi.zend_iterator_init(&self.impl);
    self.impl.funcs = functions;
    return self;
}

pub fn data(self: *@This()) *Value {
    return @ptrCast(&self.impl.data);
}

impl: c.zend_object_iterator,
