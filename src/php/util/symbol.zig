const std = @import("std");

const php = @import("../root.zig");

const Class = php.Class;
const Constant = php.Constant;
const ReturnType = php.util.ReturnType;
const WithoutError = php.util.WithoutError;

pub const Kind = enum { getter, setter, method, @"export" };
pub const Scope = enum { instance, static };

pub fn Extractor(
    comptime T: type,
    comptime kind: Kind,
    comptime scope: Scope,
) type {
    const prefix = switch (kind) {
        .getter => switch (scope) {
            .instance => "get",
            .static => "static get",
        },
        .setter => switch (scope) {
            .instance => "set",
            .static => "static set",
        },
        .method => switch (scope) {
            .instance => "call",
            .static => "static call",
        },
        .@"export" => "export",
    };
    const Self = switch (scope) {
        .instance => T,
        .static => Class.Custom(T).Static,
    };
    const names, const types = init: {
        var count: usize = 0;
        const decl_names = std.meta.declarations(T);
        for (decl_names) |decl_name| {
            if (std.mem.startsWith(u8, decl_name, prefix ++ " ")) {
                const Decl = @TypeOf(@field(T, decl_name));
                if (!check(Decl, Self, kind)) {
                    @compileError("@\"" ++ decl_name ++ "\" is an invalid " ++ @tagName(kind) ++ ": " ++ @typeName(Decl));
                }
                count += 1;
            }
        }
        var index: usize = 0;
        var names: [count][:0]const u8 = undefined;
        var types: [count]type = undefined;
        for (decl_names) |decl_name| {
            if (std.mem.startsWith(u8, decl_name, prefix ++ " ")) {
                names[index] = decl_name[prefix.len + 1 ..];
                types[index] = @TypeOf(@field(T, decl_name));
                index += 1;
            }
        }
        break :init .{ names, types };
    };
    var attributes: [names.len]std.lang.Type.Struct.FieldAttributes = undefined;
    for (&attributes) |*ptr| ptr.* = .{};
    const Container = @Struct(.auto, null, &names, &types, &attributes);
    return struct {
        pub fn get() Container {
            var result: Container = undefined;
            inline for (names) |name| {
                @field(result, name) = @field(T, prefix ++ " " ++ name);
            }
            return result;
        }
    };
}

pub fn ExportedClasses(comptime T: type) type {
    const exports = Extractor(T, .@"export", .static).get();
    const export_names = comptime std.meta.fieldNames(@TypeOf(exports));
    // get count first
    var count: usize = 0;
    inline for (export_names) |name| {
        const decl = @field(exports, name);
        if (@typeInfo(@TypeOf(decl)) == .type) {
            if (isCustomClass(decl)) count += 1;
        }
    }
    // get the names and types
    var names: [count][:0]const u8 = undefined;
    var types: [count]type = undefined;
    var attributes: [count]std.lang.Type.Struct.FieldAttributes = undefined;
    var index: usize = 0;
    for (export_names) |name| {
        const decl = @field(exports, name);
        if (@typeInfo(@TypeOf(decl)) == .type) {
            if (isCustomClass(decl)) {
                names[index] = name;
                types[index] = decl;
                attributes[index] = .{};
                index += 1;
            }
        }
    }
    return @Struct(.auto, null, &names, &types, &attributes);
}

pub fn ExportedConstants(comptime T: type) type {
    const exports = Extractor(T, .@"export", .static).get();
    const export_names = comptime std.meta.fieldNames(@TypeOf(exports));
    // get count first
    var count: usize = 0;
    for (export_names) |name| {
        const decl = @field(exports, name);
        switch (@typeInfo(@TypeOf(decl))) {
            .type => if (!isCustomClass(decl)) {
                const len = get: {
                    switch (@typeInfo(decl)) {
                        .@"struct" => |st| if (st.backing_integer != null) {
                            var bool_count: usize = 0;
                            for (st.field_types) |FT| {
                                if (FT == bool) bool_count += 1;
                            }
                            break :get bool_count;
                        },
                        .@"enum" => |en| break :get en.field_names.len,
                        else => {},
                    }
                    @compileError("Expected a custom class, enum, or packed struct, received: " ++ @typeName(decl));
                };
                count += len;
            },
            else => {
                count += 1;
            },
        }
    }
    const entries = init: {
        var entries: [count]Constant = undefined;
        var index: usize = 0;
        for (export_names) |name| {
            const decl = @field(exports, name);
            switch (@typeInfo(@TypeOf(decl))) {
                .type => if (!isCustomClass(decl)) {
                    // see if export_name is all-cap, then the rest of the name will be capitalized as well
                    const use_uppercase = for (name) |ch| {
                        if (std.ascii.isLower(ch)) break false;
                    } else true;
                    const item_names, const item_values = switch (@typeInfo(decl)) {
                        .@"struct" => |st| get: {
                            var bool_count: usize = 0;
                            for (st.field_types) |FT| {
                                if (FT == bool) bool_count += 1;
                            }
                            var names: [bool_count][:0]const u8 = undefined;
                            var values: [bool_count]c_long = undefined;
                            var value_index: usize = 0;
                            for (st.field_names, 0..) |field_name, i| {
                                if (st.field_types[i] == bool) {
                                    names[value_index] = field_name;
                                    values[value_index] = @intCast(1 << @bitOffsetOf(decl, field_name));
                                    value_index += 1;
                                }
                            }
                            break :get .{ names, values };
                        },
                        .@"enum" => |en| get: {
                            var names: [en.field_values.len][:0]const u8 = undefined;
                            var values: [en.field_values.len]c_long = undefined;
                            for (en.field_names, 0..) |field_name, i| {
                                names[i] = field_name;
                                values[i] = en.field_values[i];
                            }
                            break :get .{ names, values };
                        },
                        else => unreachable,
                    };
                    for (item_names, 0..) |item_name, i| {
                        const constant_name = create: {
                            const p_len = name.len;
                            var buffer: [p_len + 1 + item_name.len]u8 = undefined;
                            @memcpy(buffer[0..p_len], name);
                            buffer[p_len] = '_';
                            for (item_name, 0..) |ch, j| buffer[p_len + 1 + j] = switch (use_uppercase) {
                                true => std.ascii.toUpper(ch),
                                false => ch,
                            };
                            break :create buffer;
                        };
                        entries[index] = .fromAny(.static(&constant_name), item_values[i]);
                        index += 1;
                    }
                },
                else => {
                    entries[index] = .fromAny(.static(name), decl);
                    index += 1;
                },
            }
        }
        break :init entries;
    };
    return struct {
        pub fn get() @TypeOf(entries) {
            return entries;
        }
    };
}

fn check(comptime Decl: type, comptime Self: type, comptime kind: Kind) bool {
    switch (kind) {
        .getter => return checkMethod(Decl, Self, 1),
        .setter => {
            if (!checkMethod(Decl, Self, 2)) return false;
            const RT = ReturnType(Decl);
            if (WithoutError(RT) != void) return false;
            return true;
        },
        .method => return checkMethod(Decl, Self, null),
        .@"export" => return true,
    }
}

fn checkMethod(comptime FT: type, comptime Self: type, comptime arg_count: ?usize) bool {
    switch (@typeInfo(FT)) {
        .@"fn" => |f| {
            if (f.param_types.len == 0) return false;
            if (arg_count) |count| {
                if (f.param_types.len != count) return false;
            }
            const PT = f.param_types[0] orelse return false;
            switch (@typeInfo(PT)) {
                .pointer => |pt| if (pt.child != Self) return false,
                else => return false,
            }
            return true;
        },
        else => return false,
    }
}

fn isCustomClass(comptime Decl: type) bool {
    return switch (@typeInfo(Decl)) {
        .@"struct" => @hasField(Decl, "class_entry") and @FieldType(Decl, "class_entry") == Class,
        else => false,
    };
}
