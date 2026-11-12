const php = @import("php/root.zig");

pub const @"export CONST_ARRAY" = .{ 1, 2, 3, 4 };
pub const @"export CONST_OBJECT" = .{ .hello = 123, .world = 456 };

pub const @"export Hello" = php.Class.Custom(struct {
    pub const @"export array" = .{ 1, 2, 3, 4 };
    pub const @"export object" = .{ .hello = 123, .world = 456 };
});
