const php = @import("php/root.zig");
const getter = php.IniEntry.getter;
const setter = php.IniEntry.setter;

pub fn @"call greet"(self: *@This(), args: struct {
    name: []const u8,
}) !void {
    php.print("{s}, {s}!\n", .{ self.greeting, args.name });
}

pub fn @"call leave"(self: *@This()) !void {
    php.print("{s}!\n", .{self.parting});
}

pub const @"get greeting" = getter(@This(), .greeting);
pub const @"set greeting" = setter(@This(), .greeting);
pub const @"get parting" = getter(@This(), .parting);
pub const @"set parting" = setter(@This(), .parting);

greeting: []const u8 = "Hello",
parting: []const u8 = "Goodbye",
