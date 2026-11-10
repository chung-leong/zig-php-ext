const php = @import("php/root.zig");

pub fn @"call show"(_: *@This(), args: struct {
    variant: union(enum) {
        integer: i64,
        float: f64,
        boolean: bool,
    },
}) !void {
    switch (args.variant) {
        .integer => |i| php.print("integer = {d}\n", .{i}),
        .float => |f| php.print("float = {d}\n", .{f}),
        .boolean => |b| php.print("boolean = {}\n", .{b}),
    }
}
