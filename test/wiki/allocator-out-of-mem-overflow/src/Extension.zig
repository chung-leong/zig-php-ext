const std = @import("std");

const php = @import("php/root.zig");

pub fn @"call test_alloc_u16"(_: *@This()) !void {
    const slice = php.allocator.alloc(u16, std.math.maxInt(usize)) catch |err| {
        php.print("Error: {}\n", .{err});
        return;
    };
    defer php.allocator.free(slice);
}
