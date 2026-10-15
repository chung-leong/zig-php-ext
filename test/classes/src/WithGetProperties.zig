const std = @import("std");

const php = @import("php/root.zig");
const Array = php.Array;
const Object = php.Object;
const getter = Object.getter;
const PropertiesPurpose = Object.PropertiesPurpose;
const setter = Object.setter;
const String = php.String;

pub const @"get number" = getter(@This(), .number);
pub const @"set number" = setter(@This(), .number);

pub const @"get optional" = getter(@This(), .optional);
pub const @"set optional" = setter(@This(), .optional);

pub fn getProperties(_: *@This(), purpose: PropertiesPurpose) !*Array {
    php.print("(getProperties: {}) ", .{purpose});
    const arr = Array.create();
    arr.set("foo", .fromString(.static("cowboy")));
    arr.set("bar", .fromString(.static("mleczny")));
    arr.set(17, .fromFloat(std.math.pi));
    return arr;
}

number: i32 = 2001,
optional: ?i32 = null,
