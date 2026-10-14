const php = @import("root.zig");
const c = php.c;
const errable = php.util.errable;

pub fn @"fn"(comptime T: type) type {
    return struct {
        pub fn init() !void {
            if (@hasDecl(T, "init")) {
                value = try errable(T.init());
            } else {
                value = .{};
            }
        }

        pub fn deinit() void {
            if (@hasDecl(T, "deinit")) {
                value.deinit();
            }
        }

        pub fn get() *T {
            return &value;
        }

        pub fn reset(default_value: T) void {
            value = default_value;
        }

        threadlocal var value: T = undefined;
    };
}
