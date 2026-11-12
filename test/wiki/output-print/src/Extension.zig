const php = @import("php/root.zig");

pub fn @"call show"(_: *@This(), args: struct {
    string: []const u8,
    int: u32,
    float: f64,
    bool: bool,
    point: struct { x: f64, y: f64 },
}) !void {
    php.print("\"{s}\", 0x{x} {d} {} {}\n", .{
        args.string,
        args.int,
        args.float,
        args.bool,
        args.point,
    });
}
