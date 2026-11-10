const php = @import("php/root.zig");

const Something = struct {
    opaque_ptr: *anyopaque,
};
pub const @"export Something" = php.Class.Custom(Something);

pub fn @"call create"(_: *@This()) !Something {
    return .{ .opaque_ptr = @ptrFromInt(0xDEADBEEF) };
}

pub fn @"call receive"(_: *@This(), args: struct {
    something: *Something,
}) void {
    php.print("opaque_ptr = 0x{X}\n", .{
        @intFromPtr(args.something.opaque_ptr),
    });
}
