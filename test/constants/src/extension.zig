const std = @import("std");

const php = @import("php/root.zig");
const Constant = php.Constant;
const Module = php.Module;
const String = php.String;

pub const @"export CONST_BOOL" = true;
pub const @"export CONST_INT" = 1234;
pub const @"export CONST_FLOAT" = std.math.pi;
pub const @"export CONST_STRING" = "Hello world";

pub const @"export CONST_ENUM" = enum { hello, world };
pub const @"export CONST_FLAG" = packed struct {
    option_a: bool,
    option_b: bool,
    option_c: bool,
};
pub const @"export CONST_MORE" = packed struct(u8) {
    option_a: bool,
    option_b: bool,
    _: u6 = 0,
};

pub fn @"call show_constant"(_: *@This(), args: struct {
    name: *String,
}) !void {
    const constant = Constant.find(args.name) orelse return error.NotFound;
    var value = constant.value();
    value.convert(.string);
    php.print("{s}\n", .{value.string().slice()});
}
