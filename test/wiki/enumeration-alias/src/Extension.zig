const php = @import("php/root.zig");

const Fruit = enum {
    apple,
    banana,
    cherry,
    durian,

    pub const favorite: @This() = .banana;
};
pub const @"export Fruit" = php.Enum.Custom(Fruit);
