const php = @import("php/root.zig");
const Function = php.Function;

pub fn init() @This() {
    php.print("init\n", .{});
    return .{};
}

pub fn deinit(_: *@This()) void {
    php.print("deinit\n", .{});
}

pub fn freeObject(_: *@This()) !void {
    php.print("freeObject\n", .{});
}

pub fn destroyObject(_: *@This()) !void {
    php.print("destroyObject\n", .{});
}

pub fn getConstructor(_: *@This()) ?*const Function {
    php.print("getConstructor\n", .{});
    return &constructor;
}

const constructor: Function = .init(construct, .{
    .self_source = .{ .this_object = @This() },
});

fn construct(_: *@This(), args: struct {
    number: i32,
    text: []const u8,
}) !void {
    php.print("constructor: {d}, {s}\n", .{ args.number, args.text });
}
