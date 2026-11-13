const php = @import("php/root.zig");

pub fn init() !@This() {
    php.print("init\n", .{});
    return .{ .stuff = 1234 };
}

pub fn deinit(_: *@This()) void {
    php.print("deinit\n", .{});
}

pub fn moduleStartup(_: *@This(), module_type: php.Module.Type, module_no: c_int) !void {
    php.print("moduleStartup: {}, {}\n", .{ module_type, module_no });
}

pub fn moduleShutdown(_: *@This(), module_type: php.Module.Type, module_no: c_int) !void {
    php.print("moduleShutdown: {}, {}\n", .{ module_type, module_no });
}

stuff: usize,
