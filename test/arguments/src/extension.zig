const std = @import("std");

const php = @import("php/root.zig");
const InfoTable = php.InfoTable;
const Module = php.Module;
const getter = php.util.getter;
const setter = php.util.setter;

pub fn @"call printBool"(self: *@This(), args: struct {
    boolean: bool,
}) !void {
    _ = self;
    php.print("boolean = {}\n", .{args.boolean});
}

pub fn @"call printInt"(self: *@This(), args: struct {
    int: i32,
}) !void {
    _ = self;
    php.print("int = {d}\n", .{args.int});
}

pub fn @"call printUint"(self: *@This(), args: struct {
    uint: u32,
}) !void {
    _ = self;
    php.print("uint = {d}\n", .{args.uint});
}

pub fn @"call printIntFloats"(self: *@This(), args: struct {
    int: i32,
    float1: f32,
    float2: f64,
}) !void {
    _ = self;
    php.print("int = {d}, float1 = {d}, float2 = {d}\n", .{ args.int, args.float1, args.float2 });
}

pub fn @"call printString"(self: *@This(), args: struct {
    string: []const u8,
}) void {
    _ = self;
    php.print("string = {s}\n", .{args.string});
}

pub fn @"call printStrings"(self: *@This(), args: struct {
    string1: []const u8,
    string2: []const u8 = "cow",
}) void {
    _ = self;
    php.print("string1 = {s}, string2 = {s}\n", .{ args.string1, args.string2 });
}
