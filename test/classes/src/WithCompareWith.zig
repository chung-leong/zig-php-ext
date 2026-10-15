const std = @import("std");

const php = @import("php/root.zig");
const Object = php.Object;
const getter = Object.getter;
const setter = Object.setter;
const Value = php.Value;

pub const @"get value" = getter(@This(), .float);
pub const @"set value" = setter(@This(), .float);

pub fn compareWith(self: *@This(), other: Value) !c_int {
    const other_float = try other.getFloat();
    php.print("compareWith: {d}\n", .{other_float});
    return if (self.float < other_float)
        -1
    else if (self.float > other_float)
        1
    else
        0;
}

float: f64 = 0,
