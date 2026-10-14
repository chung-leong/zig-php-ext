const std = @import("std");

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

pub const @"export number" = 1234;
pub const @"export text" = "Hello world";
