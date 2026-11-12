const php = @import("php/root.zig");

pub const @"export Point" = php.Class.Custom(struct {
    x: f64 = 0,
    y: f64 = 0,

    pub fn @"get x"(self: *@This()) f64 {
        return self.x;
    }

    pub fn @"set x"(self: *@This(), value: f64) void {
        self.x = value;
    }

    pub fn @"get y"(self: *@This()) f64 {
        return self.y;
    }

    pub fn @"set y"(self: *@This(), value: f64) void {
        self.y = value;
    }

    pub fn @"get normal"(self: *@This()) f64 {
        return @sqrt(self.x * self.x + self.y * self.y);
    }
});
