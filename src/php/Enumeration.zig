const std = @import("std");

const php = @import("root.zig");
const Array = php.Array;
const c = php.c;
const Class = php.Class;
const Constant = php.Constant;
const String = php.String;
const Value = php.Value;

pub fn class(self: *const @This()) *Class {
    return @ptrCast(@constCast(self));
}

pub fn Custom(comptime T: type) type {
    const item_names, const item_values = switch (@typeInfo(T)) {
        .@"struct" => |st| switch (st.layout) {
            .@"packed" => init: {
                var count: usize = 0;
                for (st.field_types) |FT| {
                    if (FT == bool) count += 1;
                }
                var names: [count][]const u8 = undefined;
                var values: [count]comptime_int = undefined;
                var index: usize = 0;
                for (st.field_names, st.field_types) |field_name, FT| {
                    if (FT == bool) {
                        names[index] = field_name;
                        values[index] = 1 << @bitOffsetOf(T, field_name);
                        index += 1;
                    }
                }
                break :init .{ names, values };
            },
            else => @compileError("Packed struct expected, received: " ++ @typeName(T)),
        },
        .@"enum" => |en| .{ en.field_names, en.field_values },
        else => @compileError("Enum or packed struct expected, received: " ++ @typeName(T)),
    };
    return struct {
        pub fn create(name: []const u8) *@This() {
            const self: *CustomClass = .create(name, null);
            const flags: *Class.Flags = @ptrCast(&self.class().impl.ce_flags);
            flags.enumeration = true;
            const arr = self.class().constants();
            inline for (item_names, item_values) |item_name, item_value| {
                const constant: *Constant = .create(item_name, item_value);
                constant.attach(arr);
            }
            return @ptrCast(self);
        }

        pub fn register(self: *@This()) !void {
            const cc: *CustomClass = @ptrCast(@alignCast(self));
            try cc.register();
        }

        const CustomClass = Class.Custom(Empty);
    };
}

const Empty = struct {};

class_entry: Class,
