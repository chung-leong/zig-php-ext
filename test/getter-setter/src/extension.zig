const php = @import("php/root.zig");
const Class = php.Class;
const getter = php.IniEntry.getter;
const setter = php.IniEntry.setter;

pub const @"export WithNoGettersOrSetters" = Class.Custom(struct {
    hello: i32 = 123,
    world: i32 = 456,
});

pub const @"export WithNoGettersNoAutoSet" = Class.Custom(struct {
    hello: i32 = 123,
    world: i32 = 456,

    pub const @"use auto setter" = false;
});

pub const @"export WithOneGetter" = Class.Custom(struct {
    hello: i32 = 123,
    world: i32 = 456,

    pub fn @"get hello"(self: *@This()) i32 {
        return self.hello * 2;
    }
});

pub const @"export WithOneGetterAutoGet" = Class.Custom(struct {
    hello: i32 = 123,
    world: i32 = 456,

    pub fn @"get hello"(self: *@This()) i32 {
        return self.hello * 2;
    }

    pub fn @"set hello"(self: *@This(), value: i32) !void {
        if (value > 100) return error.PantsOnFire;
        self.hello = value;
    }

    pub const @"use auto getter" = true;
});

pub const @"export WithNoGettersOrSettersOneFunction" = Class.Custom(struct {
    hello: i32 = 123,
    world: i32 = 456,

    pub fn hi() void {}
});
