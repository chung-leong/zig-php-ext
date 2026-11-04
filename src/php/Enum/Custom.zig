const std = @import("std");
const builtin = @import("builtin");

const php = @import("../root.zig");
const Array = php.Array;
const Class = php.Class;
const Constant = php.Constant;
const Enum = php.Enum;
const String = php.String;

pub fn @"fn"(comptime T: type) type {
    return struct {
        pub fn @"enum"(self: *const @This()) *Enum {
            return @constCast(&self.enum_entry);
        }

        pub fn name(_: *const @This()) *String {
            return canonical_name.?;
        }

        pub fn get() *@This() {
            return registered orelse {
                if (builtin.mode == .debug) {
                    std.debug.print("Enum is not registered: {}\n", .{T});
                }
                unreachable;
            };
        }

        pub fn isRegistered() bool {
            return registered != null;
        }

        pub fn register(comptime full_name: []const u8) !*@This() {
            return registered orelse create: {
                const enum_entry: *Enum = try .register(full_name, .integer);
                const en = @typeInfo(T).@"enum";
                inline for (en.field_names, en.field_values) |field_name, field_value| {
                    enum_entry.addCase(.static(field_name), .fromAny(field_value, .{}));
                }
                const cls = enum_entry.class();
                inline for (en.decl_names) |decl_name| {
                    if (@TypeOf(@field(T, decl_name)) == T) {
                        const decl_value = @field(T, decl_name);
                        const field_index = inline for (en.field_values, 0..) |field_value, i| {
                            if (@backingInt(decl_value) == field_value) break i;
                        };
                        const field_name = en.field_names[field_index];
                        const ast_ref: *Constant.AstRef = .createClassConstFetch(cls.name(), .static(field_name));
                        // class constant registration never fails actually--returning error union only for consistency
                        const constant: *Class.Constant = try .register(decl_name, ast_ref.toValue(), cls);
                        _ = constant;
                    }
                }
                const self: *@This() = @ptrCast(enum_entry);
                registered = self;
                // when an enum is registered in multiple places, the first name encountered is
                // considered its canonical name
                canonical_name = String.static(full_name);
                break :create self;
            };
        }

        pub const custom_type: php.util.api.custom.Type = .@"enum";

        var registered: ?*@This() = null;
        var canonical_name: ?*String = null;

        enum_entry: Enum,
    };
}
