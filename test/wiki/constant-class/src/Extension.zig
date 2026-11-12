const php = @import("php/root.zig");

pub const @"export Hello" = php.Class.Custom(struct {
    pub const @"export string" = "Hello world";
    pub const @"export int" = 12345;
});
