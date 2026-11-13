const php = @import("php/root.zig");

const Point = struct {
    x: f64,
    y: f64,
};

pub fn @"call get_point"(_: *@This()) !Point {
    return .{ .x = 123, .y = 456 };
}
