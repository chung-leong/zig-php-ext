const php = @import("php/root.zig");

pub fn @"call set_text"(_: *@This(), args: struct {
    value: *php.Value,
}) !void {
    args.value.release();
    args.value.* = .fromString(.static("Hello world"));
}
