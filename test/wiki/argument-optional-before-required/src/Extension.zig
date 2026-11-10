const php = @import("php/root.zig");

pub fn @"call bar"(_: *@This(), args: struct {
    boolean: bool = true,
    number1: i32,
    number2: i32,
}) !void {
    php.print("boolean = {}, number1 = {d}, number2 = {d}\n", .{
        args.boolean,
        args.number1,
        args.number2,
    });
}
