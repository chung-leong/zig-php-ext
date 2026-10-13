const php = @import("php/root.zig");
const String = php.String;
const getter = php.Object.getter;
const setter = php.Object.setter;

pub fn @"call greet"(self: *@This(), args: struct {
    name: []const u8,
}) !void {
    php.print("{s}, {s}!\n", .{ self.greeting, args.name });
}

pub const @"get greeting" = getter(@This(), .greeting);
pub const @"set greeting" = setter(@This(), .greeting);

pub fn @"get template"(self: *@This()) *String {
    return .allocPrint("{s}, $name!", .{self.greeting});
}

greeting: []const u8 = "Hello",
