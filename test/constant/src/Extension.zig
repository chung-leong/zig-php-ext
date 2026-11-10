const std = @import("std");
pub const @"export CONST_FLOAT" = std.math.pi;

const php = @import("php/root.zig");
const Class = php.Class;
const Constant = php.Constant;
const Enum = php.Enum;
const Module = php.Module;
const String = php.String;

const Pet = enum { cat, dog, cow };

pub const @"export CONST_BOOL" = true;
pub const @"export CONST_INT" = 1234;
pub const @"export CONST_STRING" = "Hello world";
pub const @"export CONST_ARRAY" = [4]i32{ 1, 2, 3, 4 };
pub const @"export CONST_STRING_ARRAY" = [2][]const u8{ "Hello", "world" };
pub const @"export CONST_OBJECT" = .{ .cow = 123, .pig = 456 };
pub const @"export CONST_LITERAL" = .@"Hello world";
pub const @"export CONST_ENUM": Pet = .dog;

pub const @"export ConstEnum" = Enum.Custom(enum { hello, world });
pub const @"export ConstType" = Enum.Custom(enum(i32) {
    alpha = 123,
    beta = 456,
    gamma = 789,

    pub const a: @This() = .alpha;
    pub const b: @This() = .beta;
});
pub const @"export ConstFlag" = Class.Custom(packed struct {
    option_a: bool = false,
    option_b: bool = false,
    option_c: bool = false,
});
pub const @"export ConstMore" = Class.Custom(packed struct(u8) {
    option_a: bool = false,
    option_b: bool = false,
    _: u6 = 0,
});

pub const @"export EnumWithConst" = Enum.Custom(enum {
    cat,
    dog,
    monkey,

    pub const kitten: @This() = .cat;
    pub const puppy: @This() = .dog;

    pub const @"export cow" = "Mooo";
    pub const @"export puppy" = "Sad";
    pub const @"export birds" = .{ "Fat", "Angry", "Depressed" };
});
pub const @"export EnumWithMethod" = Enum.Custom(enum {
    cat,
    dog,
    bear,

    pub fn @"call hello"(self: @This()) void {
        php.print("Hello {}\n", .{self});
    }

    pub fn @"static call hello"(static: *Static) void {
        static.count += 1;
        php.print("Hello world!!! ({d})\n", .{static.count});
    }

    const Static = struct {
        count: usize = 0,
    };
});

pub fn @"call show_constant"(_: *@This(), args: struct {
    name: *String,
}) !void {
    const constant = Constant.find(args.name) orelse return error.NotFound;
    const value = constant.value().cast(.string);
    defer value.release();
    php.print("{s}\n", .{value.string().slice()});
}

pub fn @"call return_unregistered_enum"(_: *@This()) Pet {
    const a: Pet = .cow;
    return a;
}
