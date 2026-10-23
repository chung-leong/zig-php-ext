const php = @import("php/root.zig");
const getter = php.IniEntry.getter;
const setter = php.IniEntry.setter;

pub const @"export CONSTANT" = "Hello world";
pub const @"export Enum" = enum { hello, world };

pub fn @"call greet"(self: *@This(), args: struct {
    name: []const u8,
}) !void {
    php.print("{s}, {s}!\n", .{ self.greeting, args.name });
}

pub const @"get greeting" = getter(@This(), .greeting);
pub const @"set greeting" = setter(@This(), .greeting);

greeting: [:0]const u8 = "Hello",
