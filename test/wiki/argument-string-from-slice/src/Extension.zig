const php = @import("php/root.zig");

pub fn @"call hello"(_: *@This(), args: struct {
    name: []const u8,
}) !void {
    const str: *php.String = .fromOwnSlice(args.name);
    php.print("address of name = {d}\n", .{
        @intFromPtr(args.name.ptr),
    });
    php.print("address of str.slice() = {d}\n", .{
        @intFromPtr(str.slice().ptr),
    });
}
