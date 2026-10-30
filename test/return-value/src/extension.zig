const std = @import("std");

const php = @import("php/root.zig");
const Module = php.Module;

pub fn @"call returnBool"(_: *@This()) !bool {
    return true;
}

pub fn @"call returnInt"(_: *@This()) !i32 {
    return 1234;
}

pub fn @"call returnFloat"(_: *@This()) !f32 {
    return 12.5;
}

pub fn @"call returnString"(_: *@This(), args: struct {
    string: []const u8 = "Hello world",
}) []const u8 {
    return args.string;
}

pub fn @"call returnNewString"(_: *@This(), allocator: std.mem.Allocator, args: struct {
    name: []const u8 = "Alice",
}) ![]const u8 {
    return try std.fmt.allocPrint(allocator, "Hello, {s}\n", .{args.name});
}

pub fn @"call returnEnum"(_: *@This()) enum { cat, dog, turkey } {
    return .dog;
}

pub fn @"call returnFlags"(_: *@This()) packed struct(u8) {
    option1: bool = false,
    option2: bool = false,
    option3: bool = false,
    option4: bool = false,
    _: u4 = 0,
} {
    return .{ .option1 = true, .option3 = true };
}

pub fn @"call returnArray"(_: *@This()) [4]i32 {
    return .{ 1, 2, 3, 4 };
}

pub fn @"call returnVector"(_: *@This()) @Vector(3, f32) {
    return .{ 1.5, 2.5, 3.5 };
}

pub fn @"call returnOptional"(_: *@This(), args: struct { state: bool }) ?[]const u8 {
    return if (args.state) "Hello world" else null;
}

pub fn @"call returnStruct"(_: *@This()) struct {
    name: []const u8,
    age: u32,
} {
    return .{ .name = "Bigus Dickus", .age = 32 };
}

pub fn @"call returnStructArray"(_: *@This()) [3]struct {
    name: []const u8,
    age: u32,
} {
    return .{
        .{ .name = "Doctor Evil", .age = 32 },
        .{ .name = "Doctor Doom", .age = 100 },
        .{ .name = "Doctor Zhivago", .age = 45 },
    };
}
