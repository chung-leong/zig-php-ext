const std = @import("std");
const builtin = @import("builtin");

const php = @import("../root.zig");
const Array = php.Array;
const Class = php.Class;
const Constant = php.Constant;
const Enum = php.Enum;
const Object = php.Object;
const String = php.String;
const Value = php.Value;

pub fn @"fn"(comptime T: type) type {
    return struct {
        pub fn @"enum"(self: *const @This()) *Enum {
            return @constCast(&self.enum_entry);
        }

        pub fn name(_: *const @This()) *String {
            return canonical_name.?;
        }

        pub fn class(self: *const @This()) *Class {
            return self.enum_entry.class();
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

        pub fn registerExports(self: *@This(), comptime parent_name: []const u8) !void {
            const class_names = comptime std.meta.fieldNames(@TypeOf(classes));
            var class_instances: php.util.symbol.InstanceTuple(classes) = undefined;
            inline for (class_names, 0..) |class_name, i| {
                const full_class_name = parent_name ++ "\\" ++ class_name;
                class_instances[i] = try .register(full_class_name, null);
                // add the full class path as a constant
                _ = try Class.Constant.register(class_name, .fromString(.static(full_class_name)), self.class());
            }
            const enum_names = comptime std.meta.fieldNames(@TypeOf(enums));
            var enum_instances: php.util.symbol.InstanceTuple(enums) = undefined;
            inline for (enum_names, 0..) |enum_name, i| {
                const full_enum_name = parent_name ++ "\\" ++ enum_name;
                enum_instances[i] = try .register(full_enum_name);
                _ = try Class.Constant.register(enum_name, .fromString(.static(full_enum_name)), self.class());
            }
            inline for (class_instances, class_names) |custom_cls, class_name| {
                try custom_cls.registerExports(parent_name ++ "\\" ++ class_name);
            }
            inline for (enum_instances, enum_names) |custom_enum, enum_name| {
                try custom_enum.registerExports(parent_name ++ "\\" ++ enum_name);
            }
            const const_names = comptime std.meta.fieldNames(@TypeOf(constants));
            const const_types = comptime std.meta.fieldTypes(@TypeOf(constants));
            inline for (const_names, const_types) |const_name, CT| {
                // unlike global constants, it's possible to create persistent non-scalar class
                // constants using AST literals
                const value = @field(constants, const_name);
                const constant_value: Value = switch (comptime php.util.isScalarType(CT)) {
                    true => .fromAny(value, .{}),
                    false => Constant.AstRef.createLiteral(CT, value).toValue(),
                };
                _ = try Class.Constant.register(const_name, constant_value, self.class());
            }
        }

        pub const custom_type: php.util.api.custom.Type = .@"enum";
        pub const Static = php.util.api.FindStatic(T);

        const methods = php.util.symbol.MethodExporter(T, .static).get();
        const constants = php.util.symbol.ConstantExporter(T).get();
        const enums = php.util.symbol.EnumExporter(T).get();
        const classes = php.util.symbol.ClassExporter(T).get();

        const method_set = init: {
            const method_names = std.meta.fieldNames(@TypeOf(methods));
            var result: Object.MethodSet(method_names) = undefined;
            for (method_names) |method_name| {
                const method = @field(methods, method_name);
                @field(result.entries, method_name) = .init(.static(method_name), method, .{
                    .self_source = .{ .singleton = Static },
                    .is_static = true,
                });
            }
            break :init result;
        };

        var registered: ?*@This() = null;
        var canonical_name: ?*String = null;

        enum_entry: Enum,
    };
}
