const php = @import("php/root.zig");

pub const @"export Point" = php.Class.Custom(struct {
    x: f64 = 0,
    y: f64 = 0,
});
