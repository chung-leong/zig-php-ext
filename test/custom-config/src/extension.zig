const std = @import("std");
const cfg = @import("config");

const php = @import("php/root.zig");

pub fn @"call print_config"(_: *@This(), _: struct {}) !void {
    inline for (comptime std.meta.declarations(cfg)) |decl_name| {
        const decl_value = @field(cfg, decl_name);
        const fmt = switch (@TypeOf(decl_value)) {
            [:0]const u8 => "{s} = {s}\n",
            type => continue,
            else => "{s} = {}\n",
        };
        php.print(fmt, .{ decl_name, decl_value });
    }
}
