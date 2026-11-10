const php = @import("php/root.zig");

pub fn @"call foo"(_: *@This(), args: struct {
    x: f64,
    y: f64,
    z: f64,
}) !void {
    php.print("x = {d}, y = {d}, z = {d}\n", .{ args.x, args.y, args.z });
}
