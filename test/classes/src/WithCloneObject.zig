const php = @import("php/root.zig");
const Object = php.Object;
const getter = Object.getter;
const setter = Object.setter;

pub const @"get number" = getter(@This(), .number);
pub const @"set number" = setter(@This(), .number);

pub const @"get text" = getter(@This(), .text);
pub const @"set text" = setter(@This(), .text);

pub fn cloneObject(self: *@This()) !*Object {
    php.print("cloneObject\n", .{});
    const obj = Object.fromCustom(self);
    const new_custom_obj = try Object.Custom(@This()).create(obj.class());
    new_custom_obj.custom_struct = php.util.retainAny(self.*);
    new_custom_obj.flags.initialized = true;
    return new_custom_obj.object();
}

number: i32 = 1234,
text: []const u8 = "Hello world",
