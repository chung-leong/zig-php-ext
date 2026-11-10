const php = @import("php/root.zig");

pub fn @"call list_arguments"(_: *@This(), args: struct {
    arg0: u32,
    @"...": []const php.Value,
    @"???": ?*php.Array,
}) !void {
    php.print("arg1 = {d}\n", .{args.arg0});
    for (args.@"...") |arg| php.print("{}\n", .{arg.kind()});
    if (args.@"???") |named| {
        var iter = named.iterate(.{});
        while (iter.next()) |n_arg| {
            php.print("{s} = {}\n", .{ iter.key().string().slice(), n_arg.kind() });
        }
    }
}
