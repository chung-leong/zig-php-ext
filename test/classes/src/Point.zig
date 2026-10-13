const php = @import("php/root.zig");
const getter = php.Object.getter;
const setter = php.Object.setter;

pub const @"get x" = getter(@This(), .x);
pub const @"set x" = setter(@This(), .x);

pub const @"get y" = getter(@This(), .y);
pub const @"set y" = setter(@This(), .y);

x: f64 = 0,
y: f64 = 0,
