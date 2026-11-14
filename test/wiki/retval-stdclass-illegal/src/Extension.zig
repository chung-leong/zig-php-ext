const std = @import("std");

const php = @import("php/root.zig");

const Person = struct {
    name: [*c]const u8,
    profession: [*c]const u8,
};

pub fn @"call get_person"(_: *@This()) !Person {
    return .{ .name = "Norman Bates", .profession = "Hotel manager" };
}
