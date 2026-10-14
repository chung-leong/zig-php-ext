const std = @import("std");

const php = @import("root.zig");
pub const symbol = @import("util/symbol.zig");

const Array = php.Array;
const Dictionary = php.Dictionary;
const Class = php.Class;
const failure = php.failure;
const unsupported = failure.unsupported;
const List = php.List;
const Object = php.Object;
const php_al = php.allocator;
const Reference = php.Reference;
const Resource = php.Resource;
const Stream = php.Stream;
const String = php.String;
const Value = php.Value;

pub fn argCount(comptime F: type) usize {
    return switch (@typeInfo(F)) {
        .pointer => |pt| argCount(pt.child),
        .@"fn" => @typeInfo(F).@"fn".param_types.len,
        else => @compileError("Not a function or function pointer: " ++ @typeName(F)),
    };
}

pub fn ArgType(comptime F: type, comptime index: usize) type {
    return switch (@typeInfo(F)) {
        .pointer => |pt| ArgType(pt.child, index),
        .@"fn" => get: {
            const types = @typeInfo(F).@"fn".param_types;
            if (index >= types.len) @compileError("Index exceeds the argument count: " ++ @typeName(F));
            break :get types[index] orelse @compileError("Unexpected generic function: " ++ @typeName(F));
        },
        else => @compileError("Not a function or function pointer: " ++ @typeName(F)),
    };
}

pub fn ReturnType(comptime F: type) type {
    return switch (@typeInfo(F)) {
        .pointer => |pt| ReturnType(pt.child),
        .@"fn" => @typeInfo(F).@"fn".return_type orelse @compileError("Cannot determine return value type"),
        else => @compileError("Not a function or function pointer"),
    };
}

pub fn WithoutError(comptime T: type) type {
    return switch (@typeInfo(T)) {
        .error_union => |eu| eu.payload,
        else => T,
    };
}

pub fn errable(arg: anytype) !WithoutError(@TypeOf(arg)) {
    return switch (@typeInfo(@TypeOf(arg))) {
        .error_union => try arg,
        else => arg,
    };
}

pub fn hasRequiredFields(comptime T: type) bool {
    const st = @typeInfo(T).@"struct";
    return inline for (st.field_attrs) |attrs| {
        if (attrs.default_value_ptr == null) break true;
    } else false;
}

pub fn hasPointer(comptime T: anytype) bool {
    return switch (@typeInfo(T)) {
        .error_union => |eu| hasPointer(eu.payload),
        .pointer => true,
        .optional => |op| hasPointer(op.child),
        inline .@"struct", .@"union" => |st| inline for (st.field_types) |FT| {
            if (hasPointer(FT)) break true;
        } else false,
        else => false,
    };
}

pub fn getFieldDefaultValue(comptime T: type, comptime field_name: []const u8) ?@FieldType(T, field_name) {
    const st = @typeInfo(T).@"struct";
    const field_attr, const FT: type = comptime for (st.field_names, 0..) |name, i| {
        if (std.mem.eql(u8, field_name, name)) {
            break .{ st.field_attrs[i], st.field_types[i] };
        }
    } else @compileError("Struct has no field by that name: " ++ field_name);
    const opaque_ptr = field_attr.default_value_ptr orelse return null;
    const def_value_ptr: *const FT = @ptrCast(@alignCast(opaque_ptr));
    return def_value_ptr.*;
}

pub fn fieldHasDefaultValue(arg: anytype, comptime field_name: []const u8) bool {
    const T = @TypeOf(arg);
    return switch (@typeInfo(T)) {
        .@"struct" => check: {
            const def_value = getFieldDefaultValue(T, field_name) orelse return false;
            const value = @field(arg, field_name);
            break :check std.meta.eql(value, def_value);
        },
        .pointer => return fieldHasDefaultValue(arg.*, field_name),
        else => false,
    };
}

pub fn retainAny(arg: anytype) @TypeOf(arg) {
    const T = @TypeOf(arg);
    if (comptime !php.util.hasPointer(T)) return arg;
    return switch (@typeInfo(T)) {
        .error_union => if (arg) |payload| retainAny(payload) else |err| err,
        .pointer => |pt| switch (pt.size) {
            .one => switch (pt.child) {
                Array, Object, Reference, Resource, Stream, String => arg.retain(),
                else => copy: {
                    const result = php_al.create(T) catch unreachable;
                    result.* = retainAny(arg);
                    break :copy result;
                },
            },
            .slice => php_al.dupe(pt.child, arg) catch unreachable,
            else => unsupported(T),
        },
        .optional => if (arg) |payload| retainAny(payload) else null,
        .@"struct" => |st| switch (T) {
            Value => arg.retain(),
            else => if (st.backing_integer == null) copy: {
                var result: T = undefined;
                inline for (st.field_names) |field_name| {
                    @field(result, field_name) = retainAny(@field(arg, field_name));
                }
                break :copy result;
            } else arg,
        },
        .@"union" => |un| switch (T) {
            Dictionary, List => arg.retain(),
            else => if (un.tag_type) |_| switch (arg) {
                inline else => |payload, tag| @unionInit(T, @tagName(tag), retainAny(payload)),
            },
        },
        else => unreachable,
    };
}

pub fn freeAny(arg: anytype) void {
    const T = @TypeOf(arg);
    if (comptime !hasPointer(T)) return;
    return switch (@typeInfo(T)) {
        .error_union => if (arg) |payload| freeAny(payload) else |_| {},
        .pointer => |pt| switch (pt.size) {
            .one => switch (pt.child) {
                Array, Object, Reference, Resource, Stream, String => arg.release(),
                else => {
                    freeAny(arg.*);
                    php_al.destroy(arg);
                },
            },
            .slice => {
                for (arg) |element| freeAny(element);
                php_al.free(arg);
            },
            else => unsupported(T),
        },
        .optional => if (arg) |payload| freeAny(payload),
        .@"struct" => |st| switch (T) {
            Value => arg.release(),
            else => if (st.backing_integer == null) {
                inline for (st.field_names) |field_name| {
                    // attempt to free value only if it's does not match the field's default value
                    if (!fieldHasDefaultValue(arg, field_name)) {
                        const value = @field(arg, field_name);
                        freeAny(value);
                    }
                }
            },
        },
        .@"union" => |un| switch (T) {
            Dictionary, List => arg.release(),
            else => if (un.tag_type) |_| {
                switch (arg) {
                    inline else => |payload| freeAny(payload),
                }
            } else unsupported(T),
        },
        else => {},
    };
}

pub fn autoFreeable(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .error_union => |eu| autoFreeable(eu.payload),
        .pointer => |pt| switch (pt.size) {
            .one => switch (pt.child) {
                Array, Object, Reference, Resource, Stream, String => true,
                else => autoFreeable(pt.child),
            },
            .slice => autoFreeable(pt.child),
            else => false,
        },
        .optional => |op| autoFreeable(op.child),
        .@"struct" => |st| switch (T) {
            Value => true,
            else => st.backing_integer != null or comptime for (st.field_types) |FT| {
                if (!autoFreeable(FT)) break false;
            } else true,
        },
        .@"union" => |un| switch (T) {
            Dictionary, List => true,
            else => un.tag_type != null and comptime for (un.field_types) |FT| {
                if (!autoFreeable(FT)) break false;
            } else true,
        },
        else => true,
    };
}

pub inline fn camelize(comptime name: []const u8) [:0]const u8 {
    var buffer: [name.len + 1]u8 = undefined;
    var len: usize = 0;
    var capitalize = false;
    for (name) |c| {
        if (c == '_') {
            capitalize = true;
        } else if (capitalize) {
            buffer[len] = std.ascii.toUpper(c);
            len += 1;
            capitalize = false;
        } else {
            buffer[len] = c;
            len += 1;
        }
    }
    buffer[len] = 0;
    return @ptrCast(buffer[0..len]);
}
