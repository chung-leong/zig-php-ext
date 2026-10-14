const php = @import("php/root.zig");
const Object = php.Object;
const getter = Object.getter;
const setter = Object.setter;
const String = php.String;

pub const @"get number" = getter(@This(), .number);
pub const @"set number" = setter(@This(), .number);

pub fn getClassName(_: *@This()) !*String {
    php.print("getClassName\n", .{});
    return .create("DingoPower");
}

number: i32 = 2001,
