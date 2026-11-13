const php = @import("php/root.zig");

pub fn @"call get_string"(_: *@This()) ![]const u8 {
    return "Hello world";
}
