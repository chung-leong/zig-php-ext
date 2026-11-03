const php = @import("php/root.zig");
const Object = php.Object;
const getter = Object.getter;
const setter = Object.setter;
const Value = php.Value;

pub const @"get value" = getter(@This(), .float);
pub const @"set value" = setter(@This(), .float);

pub fn castObject(self: *@This(), kind: Value.Kind) !Value {
    php.print("castObject\n", .{});
    return switch (kind) {
        .boolean => .fromBoolean(self.float != 0),
        .integer => .fromInteger(@trunc(self.float)),
        .float => .fromFloat(self.float),
        .string => .fromString(.print("{d}", .{self.float})),
        else => error.InvalidOperation,
    };
}

float: f64 = 0,
