const php = @import("php/root.zig");
const Class = php.Class;
const getter = php.IniEntry.getter;
const setter = php.IniEntry.setter;

pub const @"export WithAutoGettersAutoSetters" = Class.Custom(struct {
    hello: i32 = 123,
    world: i32 = 456,

    pub const @"use auto getters" = true;
    pub const @"use auto setters" = true;
});

pub const @"export WithAutoGetters" = Class.Custom(struct {
    hello: i32 = 123,
    world: i32 = 456,

    pub const @"use auto getters" = true;
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

    pub const @"use auto getters" = true;
});
