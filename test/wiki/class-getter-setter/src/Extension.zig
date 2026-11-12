const php = @import("php/root.zig");
const getter = php.Object.getter;
const setter = php.Object.setter;

pub const @"export Point" = php.Class.Custom(struct {
    x: f64 = 0,
    y: f64 = 0,

    pub const @"get x" = getter(@This(), .x);
    pub const @"set x" = setter(@This(), .x);
    pub const @"get y" = getter(@This(), .y);
    pub const @"set y" = setter(@This(), .y);

    pub fn @"get normal"(self: *@This()) f64 {
        return @sqrt(self.x * self.x + self.y * self.y);
    }
});
