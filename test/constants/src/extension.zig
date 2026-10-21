const std = @import("std");

const php = @import("php/root.zig");
const Constant = php.Constant;
const Module = php.Module;
const String = php.String;

pub const @"export CONST_BOOL" = true;
pub const @"export CONST_INT" = 1234;
pub const @"export CONST_FLOAT" = std.math.pi;
pub const @"export CONST_STRING" = "Hello world";
pub const @"export CONST_ARRAY" = [4]i32{ 1, 2, 3, 4 };
pub const @"export CONST_STRING_ARRAY" = [2][]const u8{ "Hello", "world" };

pub const @"export ConstEnum" = enum { hello, world };
pub const @"export ConstType" = enum(i32) {
    alpha = 123,
    beta = 456,
    gamma = 789,
};
pub const @"export ConstFlag" = packed struct {
    option_a: bool,
    option_b: bool,
    option_c: bool,
};
pub const @"export ConstMore" = packed struct(u8) {
    option_a: bool,
    option_b: bool,
    _: u6 = 0,
};

pub fn @"call show_constant"(_: *@This(), args: struct {
    name: *String,
}) !void {
    const constant = Constant.find(args.name) orelse return error.NotFound;
    const value = constant.value().cast(.string);
    defer value.release();
    php.print("{s}\n", .{value.string().slice()});
}
