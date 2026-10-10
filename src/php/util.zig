const std = @import("std");

pub fn argCount(comptime F: type) usize {
    return switch (@typeInfo(F)) {
        .pointer => |pt| argCount(pt.child),
        .@"fn" => @typeInfo(F).@"fn".param_types.len,
        else => @compileError("Not a function or function pointer"),
    };
}

pub fn ArgType(comptime F: type, comptime index: usize) type {
    return switch (@typeInfo(F)) {
        .pointer => |pt| ArgType(pt.child, index),
        .@"fn" => get: {
            const types = @typeInfo(F).@"fn".param_types;
            if (index >= types.len) @compileError("Not argument");
            break :get types[index] orelse @compileError("Generic function");
        },
        else => @compileError("Not a function or function pointer"),
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

pub fn getter(comptime T: type, field: std.meta.FieldEnum(T)) RT: {
    const field_name = @tagName(field);
    const FT = @FieldType(T, field_name);
    break :RT fn (*const T) FT;
} {
    const field_name = @tagName(field);
    const FT = @FieldType(T, field_name);
    const ns = struct {
        fn @"fn"(self: *const T) FT {
            return @field(self, field_name);
        }
    };
    return ns.@"fn";
}

pub fn setter(comptime T: type, field: std.meta.FieldEnum(T)) RT: {
    const field_name = @tagName(field);
    const FT = @FieldType(T, field_name);
    break :RT fn (*T, FT) void;
} {
    const field_name = @tagName(field);
    const FT = @FieldType(T, field_name);
    const ns = struct {
        fn @"fn"(self: *T, value: FT) void {
            @field(self, field_name) = value;
        }
    };
    return ns.@"fn";
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

const Scope = enum { instance, static };

pub fn methodPrefix(comptime scope: Scope) []const u8 {
    return switch (scope) {
        .instance => "call ",
        .static => "static call ",
    };
}

pub fn methodNames(comptime T: type, comptime scope: Scope) []const [:0]const u8 {
    return nameList(T, struct {
        pub const prefix = methodPrefix(scope);

        pub fn extract(comptime decl_name: [:0]const u8) ?[:0]const u8 {
            const Decl = @TypeOf(@field(T, decl_name));
            if (@typeInfo(Decl) == .@"fn") {
                if (std.mem.startsWith(u8, decl_name, prefix)) return decl_name[prefix.len..];
            }
            return null;
        }
    });
}

pub fn getterPrefix(comptime scope: Scope) []const u8 {
    return switch (scope) {
        .instance => "get ",
        .static => "static get ",
    };
}

pub fn getterNames(comptime T: type, comptime scope: Scope) []const [:0]const u8 {
    return nameList(T, struct {
        pub const prefix = getterPrefix(scope);

        pub fn extract(comptime decl_name: [:0]const u8) ?[:0]const u8 {
            const Decl = @TypeOf(@field(T, decl_name));
            if (@typeInfo(Decl) == .@"fn") {
                if (std.mem.startsWith(u8, decl_name, prefix)) {
                    const correct = check: {
                        const f = @typeInfo(Decl).@"fn";
                        // check param count: self
                        if (f.param_types.len != 1) break :check false;
                        // check self pointer
                        switch (@typeInfo(f.param_types[0].?)) {
                            .pointer => |pt| break :check pt.child == T,
                            else => break :check false,
                        }
                    };
                    if (!correct) @compileError("Invalid getter: @\"" ++ decl_name ++ "\": " ++ @typeName(Decl));
                    return decl_name[prefix.len..];
                }
            }
            return null;
        }
    });
}

pub fn setterPrefix(comptime scope: Scope) []const u8 {
    return switch (scope) {
        .instance => "set ",
        .static => "static set ",
    };
}

pub fn setterNames(comptime T: type, comptime scope: Scope) []const [:0]const u8 {
    return nameList(T, struct {
        pub const prefix = setterPrefix(scope);

        pub fn extract(comptime decl_name: [:0]const u8) ?[:0]const u8 {
            const Decl = @TypeOf(@field(T, decl_name));
            if (@typeInfo(Decl) == .@"fn") {
                if (std.mem.startsWith(u8, decl_name, prefix)) {
                    const correct = check: {
                        const f = @typeInfo(Decl).@"fn";
                        // check param count: self + value
                        if (f.param_types.len != 2) break :check false;
                        // check self pointer
                        switch (@typeInfo(f.param_types[0].?)) {
                            .pointer => |pt| if (pt.child != T) break :check false,
                            else => break :check false,
                        }
                        // check return value
                        switch (@typeInfo(f.return_type.?)) {
                            .void => break :check true,
                            .error_union => |eu| break :check eu.child == void,
                            else => break :check false,
                        }
                    };
                    if (!correct) @compileError("Invalid setter: @\"" ++ decl_name ++ "\": " ++ @typeName(Decl));
                    return decl_name[prefix.len..];
                }
            }
            return null;
        }
    });
}

fn nameList(comptime T: type, comptime criteria: type) []const [:0]const u8 {
    const names = init: {
        var count: usize = 0;
        const decl_names = std.meta.declarations(T);
        for (decl_names) |decl_name| {
            if (criteria.extract(decl_name) != null) count += 1;
        }
        var i: usize = 0;
        var names: [count][:0]const u8 = undefined;
        for (decl_names) |decl_name| {
            if (criteria.extract(decl_name)) |n| {
                names[i] = n;
                i += 1;
            }
        }
        break :init names;
    };
    return &names;
}
