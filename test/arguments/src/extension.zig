const std = @import("std");

const php = @import("php/root.zig");
const InfoTable = php.InfoTable;
const Module = php.Module;
const getter = php.util.getter;
const setter = php.util.setter;

pub fn @"call printBool"(_: *@This(), args: struct {
    boolean: bool,
}) !void {
    php.print("boolean = {}\n", .{args.boolean});
}

pub fn @"call printInt"(_: *@This(), args: struct {
    int: i32,
}) !void {
    php.print("int = {d}\n", .{args.int});
}

pub fn @"call printUint"(_: *@This(), args: struct {
    uint: u32,
}) !void {
    php.print("uint = {d}\n", .{args.uint});
}

pub fn @"call printIntFloats"(_: *@This(), args: struct {
    int: i32,
    float1: f32,
    float2: f64 = 8.88,
}) !void {
    php.print("int = {d}, float1 = {d}, float2 = {d}\n", .{ args.int, args.float1, args.float2 });
}

pub fn @"call printString"(_: *@This(), args: struct {
    string: []const u8 = "Dingo ate my baby!",
}) void {
    php.print("string = {s}\n", .{args.string});
}

pub fn @"call printStrings"(_: *@This(), args: struct {
    string1: []const u8,
    string2: []const u8 = "cow",
}) void {
    php.print("string1 = {s}, string2 = {s}\n", .{ args.string1, args.string2 });
}

pub fn @"call printEnum"(_: *@This(), args: struct {
    animal: enum { cat, dog, monkey },
}) void {
    php.print("enum = {}\n", .{args.animal});
}

pub fn @"call printFlags"(_: *@This(), args: struct {
    flags: packed struct(u8) {
        option1: bool = false,
        option2: bool = false,
        option3: bool = false,
        option4: bool = false,
        _: u4 = 0,
    },
}) void {
    php.print("flags = {}\n", .{args.flags});
}

pub fn @"call printStringList"(_: *@This(), args: struct {
    list: [][]const u8,
}) void {
    for (args.list, 0..) |item, i| {
        php.print("{d}: {s}\n", .{ i, item });
    }
}

pub fn @"call printStruct"(_: *@This(), args: struct {
    data: struct {
        list: []const []const u8 = &.{ "hello", "world" },
        number: f64,
    },
}) void {
    php.print("number = {d}\n", .{args.data.number});
    for (args.data.list, 0..) |item, i| {
        php.print("{d}: {s}\n", .{ i, item });
    }
}

pub fn @"call printUnion"(_: *@This(), args: struct {
    input: union(enum) {
        string: []const u8,
        number: f64,
    },
}) void {
    switch (args.input) {
        .string => |str| php.print("string = {s}\n", .{str}),
        .number => |num| php.print("number = {d}\n", .{num}),
    }
}

pub fn @"call printArray"(_: *@This(), args: struct {
    array: [3]f64,
}) void {
    php.print("array = {any}\n", .{args.array});
}

pub fn @"call printVector"(_: *@This(), args: struct {
    vector: @Vector(3, f64),
}) void {
    php.print("vector = {d}\n", .{args.vector});
}
