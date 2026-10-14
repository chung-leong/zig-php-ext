const php = @import("php/root.zig");
const Object = php.Object;
const getter = Object.getter;
const setter = Object.setter;

pub const @"get number" = getter(@This(), .number);
pub const @"set number" = setter(@This(), .number);

pub const @"get text" = getter(@This(), .text);
pub const @"set text" = setter(@This(), .text);

pub fn clone(self: *@This()) !@This() {
    php.print("clone\n", .{});
    return php.util.retainAny(self.*);
}

number: i32 = 1234,
text: []const u8 = "Hello world",
