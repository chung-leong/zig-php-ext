//! Parametric struct type used for maintaining a single instance of the extension struct
//! (the argument passed to `Class.Custom`) and instances of class static structs.
const php = @import("root.zig");
const c = php.c;
const errable = php.util.errable;

pub fn _(comptime T: type) type {
    return struct {
        /// Initialize a singleton. Called when the extension first loads.
        pub fn init() !void {
            if (@hasDecl(T, "init")) {
                value = try errable(T.init());
            } else {
                value = .{};
            }
        }
        /// Free the singleton. Called when the extension is shutting down.
        pub fn deinit() void {
            if (@hasDecl(T, "deinit")) {
                value.deinit();
            }
        }
        /// Return a pointer to the singleton value
        pub fn get() *T {
            return &value;
        }
        /// Restore the singleton value to a saved state. Called when handling of a request is complete.
        pub fn reset(default_value: T) void {
            value = default_value;
        }

        threadlocal var value: T = undefined;
    };
}
