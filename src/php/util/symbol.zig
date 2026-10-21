const std = @import("std");

const php = @import("../root.zig");
const Array = php.Array;
const Class = php.Class;
const Constant = php.Constant;
const ReturnType = php.util.ReturnType;
const WithoutError = php.util.WithoutError;

pub const Scope = enum { instance, static };

pub fn GetterExporter(comptime T: type, comptime scope: Scope) type {
    return DeclarationExtractor(T, struct {
        pub fn match(comptime decl_name: []const u8, comptime decl: anytype) ?[]const u8 {
            const name = removePrefix(decl_name, "get", scope) orelse return null;
            if (!checkMethod(decl, T, scope, 1)) {
                @compileError("@\"" ++ decl_name ++ "\" is not a valid getter");
            }
            return name;
        }
    });
}

pub fn SetterExporter(comptime T: type, comptime scope: Scope) type {
    return DeclarationExtractor(T, struct {
        pub fn match(comptime decl_name: []const u8, comptime decl: anytype) ?[]const u8 {
            const name = removePrefix(decl_name, "set", scope) orelse return null;
            if (!checkMethod(decl, T, scope, 2)) {
                @compileError("@\"" ++ decl_name ++ "\" is not a valid setter");
            }
            const RT = ReturnType(@TypeOf(decl));
            if (WithoutError(RT) != void) {
                @compileError("@\"" ++ decl_name ++ "\" should return void");
            }
            return name;
        }
    });
}

pub fn MethodExporter(comptime T: type, comptime scope: Scope) type {
    return DeclarationExtractor(T, struct {
        pub fn match(comptime decl_name: []const u8, comptime decl: anytype) ?[]const u8 {
            const name = removePrefix(decl_name, "call", scope) orelse return null;
            if (!checkMethod(decl, T, scope, null)) {
                @compileError("@\"" ++ decl_name ++ "\" is not a valid method");
            }
            return name;
        }
    });
}

pub fn ClassExporter(comptime T: type) type {
    return DeclarationExtractor(T, struct {
        pub fn match(comptime decl_name: []const u8, comptime decl: anytype) ?[]const u8 {
            const name = removePrefix(decl_name, "export", .instance) orelse return null;
            return switch (@typeInfo(@TypeOf(decl))) {
                .type => if (isCustomClass(decl)) name else null,
                else => null,
            };
        }
    });
}

pub fn ConstantExporter(comptime T: type) type {
    return DeclarationExtractor(T, struct {
        pub fn match(comptime decl_name: []const u8, comptime decl: anytype) ?[]const u8 {
            const name = removePrefix(decl_name, "export", .instance) orelse return null;
            return switch (@typeInfo(@TypeOf(decl))) {
                .type => null,
                else => name,
            };
        }
    });
}

pub fn EnumExporter(comptime T: type) type {
    return DeclarationExtractor(T, struct {
        pub fn match(comptime decl_name: []const u8, comptime decl: anytype) ?[]const u8 {
            const name = removePrefix(decl_name, "export", .instance) orelse return null;
            return switch (@typeInfo(@TypeOf(decl))) {
                .type => if (isCustomClass(decl)) null else check: {
                    if (switch (@typeInfo(decl)) {
                        .@"struct" => |st| st.layout != .@"packed",
                        .@"enum" => false,
                        else => true,
                    }) @compileError("Custom class, packed struct, or enum expected, received: " ++ @typeName(decl));
                    break :check name;
                },
                else => null,
            };
        }
    });
}

fn DeclarationExtractor(comptime T: type, criteria: type) type {
    const decl_names = comptime std.meta.declarations(T);
    var count: usize = 0;
    for (decl_names) |decl_name| {
        const DeclPtr = @TypeOf(&@field(T, decl_name));
        if (@typeInfo(DeclPtr).pointer.attrs.@"const") {
            const decl = @field(T, decl_name);
            if (criteria.match(decl_name, decl)) |_| count += 1;
        }
    }
    var selected_decl_names: [count][]const u8 = undefined;
    var names: [count][]const u8 = undefined;
    var types: [count]type = undefined;
    var attributes: [count]std.lang.Type.Struct.FieldAttributes = undefined;
    var index: usize = 0;
    for (decl_names) |decl_name| {
        const DeclPtr = @TypeOf(&@field(T, decl_name));
        if (@typeInfo(DeclPtr).pointer.attrs.@"const") {
            const decl = @field(T, decl_name);
            if (criteria.match(decl_name, decl)) |name| {
                selected_decl_names[index] = decl_name;
                names[index] = name;
                types[index] = @TypeOf(decl);
                attributes[index] = .{};
                index += 1;
            }
        }
    }
    const Struct = @Struct(.auto, null, &names, &types, &attributes);
    const result = init: {
        var res: Struct = undefined;
        for (selected_decl_names, names) |decl_name, name| {
            @field(res, name) = @field(T, decl_name);
        }
        break :init res;
    };
    return struct {
        pub fn get() Struct {
            return result;
        }
    };
}

fn checkMethod(comptime arg: anytype, comptime T: type, comptime scope: Scope, comptime arg_count: ?usize) bool {
    const Self = switch (scope) {
        .instance => T,
        .static => Class.Custom(T).Static,
    };
    const FT = @TypeOf(arg);
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

fn removePrefix(comptime decl_name: []const u8, comptime action: []const u8, comptime scope: Scope) ?[]const u8 {
    const prefix = switch (scope) {
        .instance => action ++ " ",
        .static => "static " ++ action ++ " ",
    };
    return if (std.mem.startsWith(u8, decl_name, prefix)) decl_name[prefix.len..] else null;
}

fn isCustomClass(comptime Decl: type) bool {
    return switch (@typeInfo(Decl)) {
        .@"struct" => @hasField(Decl, "class_entry") and @FieldType(Decl, "class_entry") == Class,
        else => false,
    };
}

fn joinNames(comptime export_name: []const u8, comptime field_name: []const u8) []const u8 {
    const use_uppercase = comptime for (export_name) |ch| {
        if (std.ascii.isLower(ch)) break false;
    } else true;
    if (!use_uppercase) return export_name ++ "_" ++ field_name;

    const combined = create: {
        const en_len = export_name.len;
        var buffer: [en_len + 1 + field_name.len]u8 = undefined;
        @memcpy(buffer[0..en_len], export_name);
        buffer[en_len] = '_';
        for (field_name, 0..) |ch, i| buffer[en_len + 1 + i] = switch (use_uppercase) {
            true => std.ascii.toUpper(ch),
            false => ch,
        };
        break :create buffer;
    };
    return &combined;
}
