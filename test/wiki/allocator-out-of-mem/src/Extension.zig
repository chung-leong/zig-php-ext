const std = @import("std");

const php = @import("php/root.zig");

pub fn @"call test_alloc_u8"(_: *@This()) !void {
    const slice = php.allocator.alloc(u8, std.math.maxInt(isize)) catch |err| {
        php.print("Error: {}\n", .{err}); // unreachable line
        return;
    };
    defer php.allocator.free(slice);
}
