const php = @import("php/root.zig");

pub const @"export Flags" = php.Class.Custom(packed struct {
    is_cheap: bool = false,
    is_fast: bool = false,
    is_good: bool = false,

    pub const @"use auto getters" = true;
    pub const @"use auto setters" = true;
});
