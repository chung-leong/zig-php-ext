const php = @import("php/root.zig");

pub const @"export Point" = php.Class.Custom(struct {
    x: f64 = 0,
    y: f64 = 0,

    pub const @"use auto getters" = true;
    pub const @"use auto setters" = true;

    pub fn @"get normal"(self: *@This()) f64 {
        return @sqrt(self.x * self.x + self.y * self.y);
    }
});
