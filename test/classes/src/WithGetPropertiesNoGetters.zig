const std = @import("std");

const php = @import("php/root.zig");
const Array = php.Array;
const Object = php.Object;
const PropertiesPurpose = Object.PropertiesPurpose;
const String = php.String;

pub fn getProperties(_: *@This(), purpose: PropertiesPurpose) !*Array {
    php.print("(getProperties: {}) ", .{purpose});
    const arr = Array.create();
    arr.set("foo", .fromString(.static("cowboy")));
    arr.set("bar", .fromString(.static("mleczny")));
    arr.set(17, .fromFloat(std.math.pi));
    return arr;
}
