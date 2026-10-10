pub const std = @import("std");

pub const Iterator = @import("Dictionary/Iterator.zig");
const php = @import("root.zig");
const Array = php.Array;
const Object = php.Object;
const String = php.String;
const N = String.static;
const Value = php.Value;
const failure = php.failure;

pub const @"union" = union(enum) {
    pub fn addRef(self: @This()) void {
        return switch (self) {
            .array => |arr| arr.addRef(),
            .object => |obj| obj.addRef(),
        };
    }

    pub fn release(self: @This()) void {
        return switch (self) {
            .array => |arr| arr.release(),
            .object => |obj| obj.release(),
        };
    }

    pub fn retain(self: @This()) @This() {
        self.addRef();
        return self;
    }

    pub fn has(self: @This(), key: anytype) bool {
        return switch (self) {
            .array => |arr| arr.has(key),
            .object => |obj| obj.hasProperty(key) catch false,
        };
    }

    pub fn read(self: @This(), key: anytype) !Value {
        return switch (self) {
            .array => |arr| get: {
                const value = try arr.get(key);
                break :get value.retain();
            },
            .object => |obj| try obj.readProperty(key),
        };
    }

    pub fn iterate(self: @This(), options: Iterator.Options) !Iterator {
        return .init(self, options);
    }

    pub fn toValue(self: @This()) Value {
        return switch (self) {
            .array => |arr| arr.toValue(),
            .object => |obj| obj.toValue(),
        };
    }

    pub fn extract(self: *const @This(), comptime T: type) !T {
        const st = switch (@typeInfo(T)) {
            .@"struct" => |st| st,
            else => @compileError("Struct type expected, received: " ++ @typeName(T)),
        };
        var s: T = undefined;
        {
            var failure_at: usize = undefined;
            errdefer {
                inline for (st.field_names, 0..) |field_name, i| {
                    if (i == failure_at) break;
                    Value.freeAny(@field(s, field_name));
                }
            }
            inline for (st.field_names, 0..) |field_name, i| {
                errdefer failure_at = i;
                @field(s, field_name) = get: {
                    const FT = st.field_types[i];
                    if (self.has(N(field_name))) {
                        const value = try self.read(N(field_name));
                        defer value.release();
                        break :get try value.convertTo(FT);
                    } else {
                        const opaque_ptr = st.field_attrs[i].default_value_ptr orelse {
                            return failure.report("Missing field value: {s}", .{field_name});
                        };
                        const field_value_ptr: *const FT = @ptrCast(opaque_ptr);
                        break :get field_value_ptr.*;
                    }
                };
            }
        }
        return s;
    }

    array: *Array,
    object: *Object,
};
