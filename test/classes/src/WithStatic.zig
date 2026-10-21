const php = @import("php/root.zig");
const getter = php.Object.getter;
const setter = php.Object.setter;

const Static = struct {
    number: i32 = 123,
    text: []const u8 = "Chicken",
};

pub fn @"static call print"(static: *Static, _: struct {}) !void {
    php.print("number = {d}\n", .{static.number});
    php.print("text = {s}\n", .{static.text});
}

pub const @"export NUMBER" = 1234;
pub const @"export TEXT" = "Hello world";
pub const @"export ARRAY" = [3]f64{ 1.23, 0.234, 3.45 };

pub const @"export Enum" = enum { cat, dog, monkey };
pub const @"export Flag" = packed struct {
    chicken: bool,
    beef: bool,
    pork: bool,
};
