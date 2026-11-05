const php = @import("php/root.zig");
const Class = php.Class;
const getter = php.IniEntry.getter;
const setter = php.IniEntry.setter;

pub const @"export WithNoGettersOrSetters" = Class.Custom(struct {
    hello: i32 = 123,
    world: i32 = 456,
});
