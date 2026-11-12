const php = @import("php/root.zig");

var global_text: []u8 = undefined;

pub fn moduleStartup(_: *@This(), _: php.Module.Type, _: c_int) !void {
    // allocating persistent memory
    global_text = try php.allocator.print("some text", .{});
}

pub fn requestStartup(_: *@This(), _: php.Module.Type, _: c_int) !void {
    php.print("persistent string: {s}\n", .{global_text});
}

pub fn moduleShutdown(_: *@This(), _: php.Module.Type, _: c_int) !void {
    // freeing persistent memory
    php.allocator.free(global_text);
}

pub fn @"call show"(_: *@This(), args: struct {
    string: []const u8,
}) !void {
    // allocating per-request memory
    const text = try php.allocator.print("string = {s}\n", .{args.string});
    // freeing per-request memory
    defer php.allocator.free(text);
    _ = try php.write(text);
}
