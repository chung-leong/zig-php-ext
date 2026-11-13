const php = @import("php/root.zig");

pub fn @"call get_pair"(_: *@This()) @Tuple(&.{ []const u8, i32 }) {
    return .{ "Hello world", 1234 };
}
