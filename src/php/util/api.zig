const std = @import("std");

const php = @import("../root.zig");
const Array = php.Array;
const Function = php.Function;
const Module = php.Module;
const Object = php.Object;
const String = php.String;
const Value = php.Value;
const argCount = php.util.argCount;
const ArgType = php.util.ArgType;
const decamelize = php.util.decamelize;
const ReturnType = php.util.ReturnType;
const WithoutError = php.util.WithoutError;

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
    .castObject = fn (anytype, Value.Kind) Value,
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
    .getProperties = fn (anytype, Object.PropertiesPurpose) *Array,
    .getPropertyPointer = .{
        fn (anytype, *String, Value.Access) ?*Value,
        fn (anytype, *String, Value.Access, ?[*]?*anyopaque) ?*Value,
    },
    .readDimension = fn (anytype, Value, Value.Access) Value,
    .writeDimension = fn (anytype, Value, Value) void,
    .hasDimension = fn (anytype, Value, bool) bool,
    .unsetDimension = fn (anytype, Value) void,
    .countElements = fn (anytype) usize,
    .getMethod = .{
        fn (anytype, *String) *const Function,
        fn (anytype, *String, *String) *const Function,
    },
    .getConstructor = fn (anytype) ?*const Function,
    .getClassName = fn (anytype) *String,
    .compareWith = fn (anytype, Value) c_int,
    .getClosure = fn (anytype, bool) Object.ClosureResult,
    .getGarbageCollection = fn (anytype) Object.GarbageCollectionResult,
    .doOperation = fn (Object.Opcode, Value, Value) Value,
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

            if (@hasDecl(T, "init")) {
                const Init = @TypeOf(T.init);
                const arg_count = argCount(Init);
                const Arg0 = switch (arg_count) {
                    0 => struct {},
                    1 => ArgType(Init, 0),
                    else => void,
                };
                if (@typeInfo(Arg0) != .@"struct") {
                    @compileError("init() should accept a single struct as its sole argument");
                }
            } else if (@hasDecl(T, "initSelf")) {
                const InitSelf = @TypeOf(T.initSelf);
                const arg_count = argCount(InitSelf);
                const Arg0 = switch (arg_count) {
                    1 => struct {},
                    2 => php.util.ArgType(InitSelf, 1),
                    else => void,
                };
                if (@typeInfo(Arg0) != .@"struct") {
                    @compileError("initSelf() should accept a single struct as its sole argument");
                }
            }
            if (@hasDecl(T, "deinit")) {
                const Deinit = @TypeOf(T.deinit);
                const arg_count = argCount(Deinit);
                const Arg0 = switch (arg_count) {
                    0 => void,
                    else => ArgType(Deinit, 0),
                };
                if (@typeInfo(Arg0) != .pointer or @typeInfo(Arg0).pointer.child != T) {
                    @compileError("deinit() should accept a self pointer");
                }
                if (arg_count > 1) {
                    @compileError("deinit() should accept no argument");
                }
                if (ReturnType(Deinit) != void) {
                    @compileError("deinit() should return void");
                }
            }
        }
    };
}

pub const CustomOpaque = opaque {};

pub fn isCustomType(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .@"struct" => @hasDecl(T, "CustomOpaque") and T.CustomOpaque == CustomOpaque,
        else => false,
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
        if (std.mem.startsWith(u8, decl_name, "get ")) {
            const Handler = @TypeOf(@field(T, decl_name));
            checkGetter(T, Handler) catch |err| {
                const err_msg = decamelize(@errorName(err));
                @compileError(err_msg ++ ": " ++ fnName(decl_name) ++ " is not a valid getter");
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
        if (std.mem.startsWith(u8, decl_name, "set ")) {
            const Handler = @TypeOf(@field(T, decl_name));
            checkSetter(T, Handler) catch |err| {
                const err_msg = decamelize(@errorName(err));
                @compileError(err_msg ++ ": " ++ fnName(decl_name) ++ " is not a valid setter");
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
        if (std.mem.startsWith(u8, decl_name, "call ")) {
            const Handler = @TypeOf(@field(T, decl_name));
            checkMethod(T, Handler) catch |err| {
                const err_msg = decamelize(@errorName(err));
                @compileError(err_msg ++ ": " ++ fnName(decl_name) ++ " is not a valid method");
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
                @compileError(err_msg ++ ": " ++ fnName(decl_name) ++ " should be " ++ p_name);
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
            if (F_RT != P_RT) return error.IncorrectReturnValue;
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
                if (checkHandler(Self, FT, PT)) {
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
        if (std.mem.startsWith(u8, decl_name, "static get ")) {
            @compileError("PHP currently does not support dynamic static setters/getters");
        }
    }
}

fn checkStaticSetters(comptime T: type, comptime _: type) void {
    const st = @typeInfo(T).@"struct";
    inline for (st.decl_names) |decl_name| {
        if (std.mem.startsWith(u8, decl_name, "static set ")) {
            @compileError("PHP currently does not support dynamic static setters/getters");
        }
    }
}

fn checkStaticMethods(comptime T: type, comptime S: type) void {
    const st = @typeInfo(T).@"struct";
    inline for (st.decl_names) |decl_name| {
        if (std.mem.startsWith(u8, decl_name, "static call ")) {
            const Handler = @TypeOf(@field(T, decl_name));
            checkMethod(S, Handler) catch |err| {
                const err_msg = decamelize(@errorName(err));
                @compileError(err_msg ++ ": " ++ fnName(decl_name) ++ " is not a valid static method");
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
                @compileError(err_msg ++ ": " ++ fnName(decl_name) ++ " should be " ++ p_name);
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

fn fnName(comptime name: []const u8) []const u8 {
    if (std.mem.indexOfScalar(u8, name, ' ') == null) return name ++ "()";
    const quoted_name = init: {
        var buffer: [name.len + 5]u8 = undefined;
        buffer[0] = '@';
        buffer[1] = '"';
        @memcpy(buffer[2 .. name.len + 2], name);
        buffer[name.len + 2] = '"';
        buffer[name.len + 3] = '(';
        buffer[name.len + 4] = ')';
        break :init buffer;
    };
    return &quoted_name;
}

fn prototypeName(comptime prototype: anytype) []const u8 {
    @setEvalBranchQuota(2000000);
    return switch (@typeInfo(@TypeOf(prototype))) {
        .type => get: {
            var name: []const u8 = "fn (";
            const f = @typeInfo(prototype).@"fn";
            for (f.param_types, 0..) |param_type, i| {
                const prefix = if (i > 0) ", " else "";
                name = name ++ prefix ++ if (param_type) |PT| @typeName(PT) else "*@This()";
            }
            name = name ++ ") !" ++ @typeName(f.return_type.?);

            break :get name;
        },
        .@"struct" => |st| init: {
            var name: []const u8 = "";
            for (st.field_names) |field_name| {
                const PT = @field(prototype, field_name);
                const p_name = prototypeName(PT);
                name = switch (name.len > 0) {
                    false => p_name,
                    true => name ++ " or " ++ p_name,
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
        if (std.mem.startsWith(u8, decl_name, "static ") or std.mem.eql(u8, decl_name, "getStaticMethod")) {
            const Decl = @TypeOf(@field(T, decl_name));
            switch (@typeInfo(Decl)) {
                .@"fn" => |f| {
                    if (f.param_types.len > 0) {
                        if (f.param_types[0]) |PT| {
                            switch (@typeInfo(PT)) {
                                .pointer => |pt| return pt.child,
                                else => {},
                            }
                        }
                    }
                },
                else => {},
            }
        }
    }
    return void;
}
