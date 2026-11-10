const std = @import("std");

const php = @import("../root.zig");
const Array = php.Array;
const Class = php.Class;
const Constant = php.Constant;
const Enum = php.Enum;
const IniEntry = php.IniEntry;
const Object = php.Object;
const fieldCount = php.util.fieldCount;
const functionCount = php.util.functionCount;
const ReturnType = php.util.ReturnType;
const WithoutError = php.util.WithoutError;

pub const Scope = enum { instance, static };
pub const Purpose = enum { module, object };

pub fn GetterExporter(comptime T: type, comptime scope: Scope, comptime purpose: Purpose) type {
    const DefinedGetterExtractor = DeclarationExtractor(T, struct {
        pub fn match(comptime decl_name: []const u8, comptime decl: anytype) ?[]const u8 {
            const name = removePrefix(decl_name, "get", scope) orelse return null;
            if (!checkMethod(decl, T, scope, 1)) {
                @compileError("@\"" ++ decl_name ++ "\" is not a valid getter");
            }
            return name;
        }
    });
    const user_auto_getters = switch (@hasDecl(T, "use auto getters")) {
        true => T.@"use auto getters",
        false => false,
    };
    if (!user_auto_getters) return DefinedGetterExtractor;
    const defined = DefinedGetterExtractor.get();
    // return struct type that adds auto-getters
    return GetterSetterGenerator(T, scope, defined, switch (purpose) {
        .module => IniEntry.getter,
        .object => Object.getter,
    });
}

pub fn SetterExporter(comptime T: type, comptime scope: Scope, comptime purpose: Purpose) type {
    const DefinedSetterExtractor = DeclarationExtractor(T, struct {
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
    const user_auto_setters = switch (@hasDecl(T, "use auto setters")) {
        true => T.@"use auto setters",
        false => false,
    };
    if (!user_auto_setters) return DefinedSetterExtractor;
    const defined = DefinedSetterExtractor.get();
    // return struct type that adds auto-getters
    return GetterSetterGenerator(T, scope, defined, switch (purpose) {
        .module => IniEntry.setter,
        .object => Object.setter,
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
            if (@typeInfo(@TypeOf(decl)) != .type) return null;
            return if (comptime php.util.api.isCustomType(decl)) switch (decl.custom_type) {
                .class => removePrefix(decl_name, "export", .instance),
                else => null,
            } else null;
        }
    });
}

pub fn ConstantExporter(comptime T: type) type {
    return DeclarationExtractor(T, struct {
        pub fn match(comptime decl_name: []const u8, comptime decl: anytype) ?[]const u8 {
            const name = removePrefix(decl_name, "export", .instance) orelse return null;
            if (@typeInfo(@TypeOf(decl)) != .type) return name;
            if (comptime php.util.api.isCustomType(decl)) switch (decl.custom_type) {
                .class, .@"enum" => return null,
                else => |tag| @compileError("Expected custom class or enum type, received: custom " ++ @tagName(tag)),
            } else @compileError("Expected custom type or constant value, received: " ++ @typeName(decl));
        }
    });
}

pub fn EnumExporter(comptime T: type) type {
    return DeclarationExtractor(T, struct {
        pub fn match(comptime decl_name: []const u8, comptime decl: anytype) ?[]const u8 {
            if (@typeInfo(@TypeOf(decl)) != .type) return null;
            return if (comptime php.util.api.isCustomType(decl)) switch (decl.custom_type) {
                .@"enum" => removePrefix(decl_name, "export", .instance),
                else => null,
            } else null;
        }
    });
}

pub fn InstanceTuple(types: anytype) type {
    const names = comptime std.meta.fieldNames(@TypeOf(types));
    var by_index: [names.len]type = undefined;
    for (names, 0..) |name, i| {
        by_index[i] = *@field(types, name);
    }
    return @Tuple(&by_index);
}

fn DeclarationExtractor(comptime T: type, criteria: type) type {
    @setEvalBranchQuota(2000000);
    const decl_names = comptime std.meta.declarations(T);
    const max_len = decl_names.len;
    var selected_decl_names: [max_len][]const u8 = undefined;
    var names: [max_len][]const u8 = undefined;
    var types: [max_len]type = undefined;
    var attributes: [max_len]std.lang.Type.Struct.FieldAttributes = undefined;
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
    const Struct = @Struct(.auto, null, names[0..index], types[0..index], attributes[0..index]);
    const result = init: {
        var res: Struct = undefined;
        for (selected_decl_names[0..index], names[0..index]) |decl_name, name| {
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

fn GetterSetterGenerator(comptime T: type, comptime scope: Scope, defined: anytype, create_fn: anytype) type {
    @setEvalBranchQuota(2000000);
    const Self = switch (scope) {
        .instance => T,
        .static => switch (@typeInfo(T)) {
            .@"enum" => Enum.Custom(T).Static,
            else => Class.Custom(T).Static,
        },
    };
    const Defined = @TypeOf(defined);
    const max_len = fieldCount(T) + fieldCount(Defined);
    var field_types: [max_len]type = undefined;
    var field_names: [max_len][]const u8 = undefined;
    var field_attrs: [max_len]std.lang.Type.Struct.FieldAttributes = undefined;
    var index: usize = 0;
    const FieldEnum = std.meta.FieldEnum(T);
    const d_st = @typeInfo(Defined).@"struct";
    // copy user-defined getters first
    inline for (d_st.field_names, d_st.field_types) |field_name, FT| {
        field_names[index] = field_name;
        field_types[index] = FT;
        field_attrs[index] = .{};
        index += 1;
    }
    // then generate getters for remaining fields
    const st = @typeInfo(T).@"struct";
    inline for (st.field_names, st.field_types) |field_name, FT| {
        if (!@hasField(Defined, field_name) and comptime php.util.autoConvertible(FT)) {
            field_types[index] = @TypeOf(create_fn(Self, @field(FieldEnum, field_name)));
            field_names[index] = field_name;
            field_attrs[index] = .{};
            index += 1;
        }
    }
    const Struct = @Struct(.auto, null, field_names[0..index], field_types[0..index], field_attrs[0..index]);
    const result = comptime init: {
        var result: Struct = undefined;
        for (d_st.field_names) |field_name| {
            @field(result, field_name) = @field(defined, field_name);
        }
        for (st.field_names, st.field_types) |field_name, FT| {
            if (!@hasField(Defined, field_name) and php.util.autoConvertible(FT)) {
                @field(result, field_name) = create_fn(Self, @field(FieldEnum, field_name));
            }
        }
        break :init result;
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
        .static => switch (@typeInfo(T)) {
            .@"enum" => Enum.Custom(T).Static,
            else => Class.Custom(T).Static,
        },
    };
    const FT = @TypeOf(arg);
    switch (@typeInfo(FT)) {
        .@"fn" => |f| {
            if (f.param_types.len == 0) return false;
            if (arg_count) |count| {
                if (f.param_types.len != count) return false;
            }
            const PT = f.param_types[0] orelse return false;
            return switch (@typeInfo(PT)) {
                .pointer => |pt| pt.child == Self,
                .@"enum" => PT == Self,
                else => false,
            };
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
