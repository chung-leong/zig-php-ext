const std = @import("std");

const php = @import("../root.zig");
const Function = php.Function;
const Module = php.Module;
const Object = php.Object;
const String = php.String;
const Value = php.Value;
const WithoutError = php.until.WithoutError;
const decamelize = php.util.decamelize;

pub const module_prototypes = .{
    .moduleStartup = fn (anytype, Module.Type, c_int) void,
    .moduleShutdown = fn (anytype, Module.Type, c_int) void,
    .requestStartup = fn (anytype, Module.Type, c_int) void,
    .requestShutdown = fn (anytype, Module.Type, c_int) void,
    .infoRequest = fn (anytype, *Module) void,
};

pub const object_prototypes = .{
    .freeObject = fn (anytype) void,
    .destroyObject = fn (anytype) void,
    .cloneObject = fn (anytype) *Object,
    .castObject = fn (anytype, Value.Kind) ?*Object,
    .readProperty = .{
        fn (anytype, *String, Value.Access) Value,
        fn (anytype, *String, Value.Access, ?[*]?*anyopaque) Value,
    },
    .writeProperty = .{
        fn (anytype, *String, Value) void,
        fn (anytype, *String, Value, ?[*]?*anyopaque) void,
    },
    .hasProperty = .{
        fn (anytype, *String) bool,
        fn (anytype, *String, ?[*]?*anyopaque) bool,
    },
    .unsetProperty = .{
        fn (anytype, *String) void,
        fn (anytype, *String, ?[*]?*anyopaque) void,
    },
    .getProperties = .{
        fn (anytype, Object.PropertiesPurpose) void,
    },
    .getPropertyPointer = .{
        fn (anytype, *String, Value.Access) ?*Value,
        fn (anytype, *String, Value.Access, ?[*]?*anyopaque) ?*Value,
    },
    .readDimension = fn (anytype, Value, Value.Access) Value,
    .writeDimension = fn (anytype, Value, Value) void,
    .hasDimension = fn (anytype, Value, bool) void,
    .unsetDimension = fn (anytype, Value) void,
    .countElements = fn (anytype, Value) usize,
    .getMethod = .{
        fn (anytype, *String) *const Function,
        fn (anytype, *String, *String) *const Function,
    },
    .getConstructor = fn (anytype) *Function,
    .getClassName = fn (anytype) *String,
    .compareWith = fn (anytype, Value) c_int,
    .getClosure = fn (anytype, bool) Object.ClosureResult,
    .getGarbageCollection = fn (anytype) Object.GarbageCollectionResult,
    .doOperation = fn (u8, Value, Value) Value,
};

pub const class_prototypes = .{
    .getStaticMethod = fn (anytype, *String) ?*const Function,
};

pub fn ModuleValidator(comptime T: type) type {
    return struct {
        pub fn check() void {
            checkStruct(T);
            checkGetters(T);
            checkSetters(T);
            checkHandlers(T, module_prototypes);
        }
    };
}

pub fn ClassValidator(comptime T: type) type {
    return struct {
        pub fn check() void {
            checkStruct(T);
            checkGetters(T);
            checkSetters(T);
            checkMethods(T);
            checkHandlers(T, object_prototypes);
            const Static = FindStatic(T);
            checkStaticGetters(T, Static);
            checkStaticSetters(T, Static);
            checkStaticMethods(T, Static);
            checkStaticHandlers(T, Static, class_prototypes);
        }
    };
}

fn checkStruct(comptime T: type) void {
    if (@typeInfo(T) != .@"struct") {
        @compileError("Struct expected, received: " ++ @typeName(T));
    }
}

fn checkGetters(comptime T: type) void {
    const st = @typeInfo(T).@"struct";
    inline for (st.decl_names) |decl_name| {
        if (std.mem.startsWith(decl_name, "get ")) {
            const Handler = @TypeOf(@field(T, decl_name));
            checkGetter(T, Handler) catch |err| {
                const err_msg = decamelize(@errorName(err));
                @compileError(err_msg ++ ": @\"" ++ decl_name ++ "\" is not a valid getter");
            };
        }
    }
}

fn checkGetter(comptime Self: type, comptime FT: type) !void {
    const fi = @typeInfo(FT).@"fn";
    if (fi.param_types.len != 1) return error.IncorrectArgumentCount;
    try checkSelf(Self, fi.param_types[0] orelse return);
}

fn checkSetters(comptime T: type) void {
    const st = @typeInfo(T).@"struct";
    inline for (st.decl_names) |decl_name| {
        if (std.mem.startsWith(decl_name, "set ")) {
            const Handler = @TypeOf(@field(T, decl_name));
            checkSetter(T, Handler) catch |err| {
                const err_msg = decamelize(@errorName(err));
                @compileError(err_msg ++ ": @\"" ++ decl_name ++ "\" is not a valid setter");
            };
        }
    }
}

fn checkSetter(comptime Self: type, comptime FT: type) !void {
    const fi = @typeInfo(FT).@"fn";
    if (fi.param_types.len != 2) return error.IncorrectArgumentCount;
    try checkSelf(Self, fi.param_types[0] orelse return);
    const F_RT = WithoutError(fi.return_type.?);
    if (F_RT != void) return error.IncorrectReturnValue;
}

fn checkMethods(comptime T: type) void {
    const st = @typeInfo(T).@"struct";
    inline for (st.decl_names) |decl_name| {
        if (std.mem.startsWith(decl_name, "call ")) {
            const Handler = @TypeOf(@field(T, decl_name));
            checkMethod(T, Handler) catch |err| {
                const err_msg = decamelize(@errorName(err));
                @compileError(err_msg ++ ": @\"" ++ decl_name ++ "\" is not a valid method");
            };
        }
    }
}

fn checkMethod(comptime Self: type, comptime FT: type) !void {
    const fi = @typeInfo(FT).@"fn";
    if (fi.param_types.len != 2) return error.IncorrectArgumentCount;
    try checkSelf(Self, fi.param_types[0] orelse return);
    if (@typeInfo(fi.param_types[1] orelse return) != .@"struct") {
        return error.ArgumentIsNotAStruct;
    }
}

fn checkHandlers(comptime T: type, comptime prototypes: anytype) void {
    const st = @typeInfo(T).@"struct";
    inline for (st.decl_names) |decl_name| {
        const MP = @TypeOf(prototypes);
        if (@hasField(MP, decl_name)) {
            const prototype = @field(prototypes, decl_name);
            const Handler = @TypeOf(@field(T, decl_name));
            checkHandler(T, Handler, prototype) catch |err| {
                const err_msg = decamelize(@errorName(err));
                const p_name = prototypeName(prototype);
                @compileError(err_msg ++ ": @\"" ++ decl_name ++ "\" should be " ++ p_name);
            };
        }
    }
}

fn checkHandler(comptime Self: type, comptime FT: type, comptime prototype: anytype) !void {
    switch (@typeInfo(@TypeOf(prototype))) {
        .type => {
            const PT = prototype;
            const fi = @typeInfo(FT).@"fn";
            const pi = @typeInfo(PT).@"fn";
            if (fi.param_types.len != pi.param_types.len) return error.IncorrectArgumentCount;
            const F_RT = WithoutError(fi.return_type.?);
            const P_RT = pi.return_type.?;
            if (F_RT == P_RT) return error.IncorrectReturnValue;
            for (pi.param_types, fi.param_types) |pi_param_type, fi_param_type| {
                const F_AT = fi_param_type orelse continue;
                if (pi_param_type) |P_AT| {
                    if (F_AT != P_AT) return error.IncorrectArgument;
                } else {
                    try checkSelf(Self, F_AT);
                }
            }
        },
        .@"struct" => |st| {
            for (st.field_names, 0..) |field_name, i| {
                const PT = @field(prototype, field_name);
                if (checkHandler(FT, PT)) {
                    return;
                } else |err| {
                    if (err != error.IncorrectArgumentCount or i == st.field_names.len - 1) {
                        return err;
                    }
                }
            }
        },
        else => unreachable,
    }
}

fn checkStaticGetters(comptime T: type, comptime _: type) void {
    const st = @typeInfo(T).@"struct";
    inline for (st.decl_names) |decl_name| {
        if (std.mem.startsWith(decl_name, "static get ")) {
            @compileError("PHP currently does not support dynamic static setters/getters");
        }
    }
}

fn checkStaticSetters(comptime T: type, comptime _: type) void {
    const st = @typeInfo(T).@"struct";
    inline for (st.decl_names) |decl_name| {
        if (std.mem.startsWith(decl_name, "static set ")) {
            @compileError("PHP currently does not support dynamic static setters/getters");
        }
    }
}

fn checkStaticMethods(comptime T: type, comptime S: type) void {
    const st = @typeInfo(T).@"struct";
    inline for (st.decl_names) |decl_name| {
        if (std.mem.startsWith(decl_name, "static call ")) {
            const Handler = @TypeOf(@field(T, decl_name));
            checkMethod(S, Handler) catch |err| {
                const err_msg = decamelize(@errorName(err));
                @compileError(err_msg ++ ": @\"" ++ decl_name ++ "\" is not a valid static method");
            };
        }
    }
}

fn checkStaticHandlers(comptime T: type, comptime S: type, comptime prototypes: anytype) void {
    const st = @typeInfo(T).@"struct";
    inline for (st.decl_names) |decl_name| {
        const MP = @TypeOf(prototypes);
        if (@hasField(MP, decl_name)) {
            const prototype = @field(prototypes, decl_name);
            const Handler = @TypeOf(@field(T, decl_name));
            checkHandler(S, Handler, prototype) catch |err| {
                const err_msg = decamelize(@errorName(err));
                const p_name = prototypeName(prototype);
                @compileError(err_msg ++ ": @\"" ++ decl_name ++ "\" should be " ++ p_name);
            };
        }
    }
}

fn checkSelf(comptime Self: type, comptime AT: type) !void {
    switch (@typeInfo(AT)) {
        .pointer => |pt| if (pt.child != Self) return error.IncorrectSelfArgument,
        else => return error.IncorrectSelfArgument,
    }
}

fn prototypeName(comptime prototype: anytype) []const u8 {
    @setEvalBranchQuota(2000000);
    return switch (@typeInfo(@TypeOf(prototype))) {
        .type => @typeName(prototype),
        .@"struct" => |st| init: {
            var name: []const u8 = "";
            for (st.field_names) |field_name| {
                const PT = @field(prototype, field_name);
                name = switch (name.len > 0) {
                    false => @typeName(PT),
                    true => name ++ " or " ++ @typeName(PT),
                };
            }
            break :init name;
        },
        else => unreachable,
    };
}

fn FindStatic(comptime T: type) type {
    const st = @typeInfo(T).@"struct";
    inline for (st.decl_names) |decl_name| {
        if (std.mem.startsWith(decl_name, "static ") or std.mem.eql(decl_name, "getStaticMethod")) {
            const Decl = @TypeOf(@field(T, decl_name));
            switch (@typeInfo(Decl)) {
                .@"fn" => |f| {
                    if (f.param_types.len > 0) {
                        if (f.param_types[0]) |PT| return PT;
                    }
                },
            }
        }
    }
    return void;
}
