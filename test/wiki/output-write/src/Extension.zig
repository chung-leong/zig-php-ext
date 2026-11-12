const php = @import("php/root.zig");

pub fn @"call write"(_: *@This(), args: struct {
    bytes: []const u8,
}) !void {
    const written = try php.write(args.bytes);
    php.print("written = {d}\n", .{written});
    php.flush();
}
