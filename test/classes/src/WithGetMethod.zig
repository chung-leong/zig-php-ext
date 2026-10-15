const php = @import("php/root.zig");
const Function = php.Function;
const String = php.String;

pub fn @"call foo"(_: *@This(), _: struct {}) void {
    php.print("foo\n", .{});
}

pub fn bar(_: *@This(), _: struct {}) void {
    php.print("bar\n", .{});
}

pub fn getMethod(_: *@This(), name: *String) !*const Function {
    php.print("getMethod\n", .{});
    if (name.matchSlice("bar")) {
        return &function_bar;
    } else {
        return error.Undefined;
    }
}

const function_bar: Function = .init(bar, .{ .self_source = .{ .this_object = @This() } });
