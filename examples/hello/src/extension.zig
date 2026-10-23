const std = @import("std");

const php = @import("php/root.zig");
const getter = php.IniEntry.getter;
const setter = php.IniEntry.setter;

pub const @"export CONSTANT" = "Hello world";
pub const @"export Enum" = enum { hello, world };

pub fn @"call greet"(self: *@This(), args: struct {
    recipient: union(enum) {
        one: []const u8,
        multiple: [][]const u8,
    },
}) !void {
    switch (args.recipient) {
        .one => |name| php.print("{s}, {s}!\n", .{ self.greeting, name }),
        .multiple => |names| for (names) |name| {
            if (std.mem.eql(u8, name, "Dan")) {
                return error.TheManIsDeaf;
            }
            php.print("{s}, {s}!\n", .{ self.greeting, name });
        },
    }
}

pub const @"get greeting" = getter(@This(), .greeting);
pub const @"set greeting" = setter(@This(), .greeting);

greeting: [:0]const u8 = "Hello",
