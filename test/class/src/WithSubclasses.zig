const php = @import("php/root.zig");
const Class = php.Class;
const Object = php.Object;
const getter = Object.getter;

pub const @"export SubclassA" = Class.Custom(struct {
    pub const @"export hello" = "Hello";
    pub const @"export Animal" = enum { cat, dog, cow };
});

pub const @"export SubclassB" = Class.Custom(struct {
    pub const @"get hello" = getter(@This(), .greeting);

    greeting: []const u8 = "Hello world",
});
