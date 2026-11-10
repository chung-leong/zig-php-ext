const php = @import("php/root.zig");

pub fn @"call list_arguments"(_: *@This(), args: struct {
    arg0: u32,
    @"...": []const php.Value,
}) !void {
    php.print("arg0 = {d}\n", .{args.arg0});
    for (args.@"...") |arg| php.print("{}\n", .{arg.kind()});
}
