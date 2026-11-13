const php = @import("php/root.zig");

pub fn init() !@This() {
    php.print("init: counter = 0\n", .{});
    return .{ .count = 0 };
}

pub fn deinit(self: *@This()) void {
    php.print("deinit: counter = {d}\n", .{self.count});
}

pub fn requestStartup(self: *@This(), _: php.Module.Type, _: c_int) !void {
    self.count += 1;
    php.print("requestStartup: counter = {d}\n", .{self.count});
}

pub fn requestShutdown(self: *@This(), _: php.Module.Type, _: c_int) !void {
    php.print("requestShutdown: counter = {d}\n", .{self.count});
}

count: usize,
