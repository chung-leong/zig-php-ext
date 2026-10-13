const php = @import("php/root.zig");
const getter = php.Object.getter;
const setter = php.Object.setter;

pub const @"get real_name" = getter(@This(), .real_name);
pub const @"set real_name" = setter(@This(), .real_name);

pub const @"get superhero_name" = getter(@This(), .superhero_name);
pub const @"set superhero_name" = setter(@This(), .superhero_name);

real_name: ?[]const u8 = null,
superhero_name: ?[]const u8 = null,
