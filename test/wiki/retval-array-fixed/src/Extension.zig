const php = @import("php/root.zig");

pub fn @"call get_array"(_: *@This()) [4]i32 {
    return .{ 10, 20, 30, 40 };
}
