const std = @import("std");

const php = @import("php/root.zig");

const Person = struct {
    name: []const u8,
    profession: []const u8,
};

pub fn @"call get_athletes"(_: *@This(), allocator: std.mem.Allocator) ![]Person {
    const persons = try allocator.alloc(Person, 3);
    persons[0] = .{
        .name = try allocator.dupe(u8, "Joe Montana"),
        .profession = try allocator.dupe(u8, "Football player"),
    };
    persons[1] = .{
        .name = try allocator.dupe(u8, "Joe DiMaggio"),
        .profession = try allocator.dupe(u8, "Baseball player"),
    };
    persons[2] = .{
        .name = try allocator.dupe(u8, "Joe Frazier"),
        .profession = try allocator.dupe(u8, "Boxer"),
    };
    return persons;
}
