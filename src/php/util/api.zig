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

/// Function prototypes of module handlers. Though not depicted as such, all functions can in fact return errors.
pub const module_prototypes = .{
    .moduleStartup = fn (anytype, Module.Type, c_int) void,
    .moduleShutdown = fn (anytype, Module.Type, c_int) void,
    .requestStartup = fn (anytype, Module.Type, c_int) void,
    .requestShutdown = fn (anytype, Module.Type, c_int) void,
    .infoRequest = fn (anytype, *Module) void,
};
/// Function prototypes of object handlers. Though not depicted as such, all functions can in fact return errors.
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
    .getProperties = fn (anytype, Object.PropertiesPurpose) ?*Array,
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
/// Function prototypes of class handlers. Though not depicted as such, all functions can in fact return errors.
pub const class_prototypes = .{
    .getStaticMethod = fn (anytype, *String) ?*const Function,
};
/// Scan through declared functions whose names start with "static " to find the static self pointer.
pub fn FindStatic(comptime T: type) type {
    var S: ?type = null;
    for (comptime std.meta.declarations(T)) |decl_name| {
        if (std.mem.startsWith(u8, decl_name, "static ") or std.mem.eql(u8, decl_name, "getStaticMethod")) {
            const Decl = @TypeOf(@field(T, decl_name));
            if (@typeInfo(Decl) == .@"fn") {
                const f = @typeInfo(Decl).@"fn";
                const arg0_type: ?type = find: {
                    if (f.param_types.len > 0) {
                        if (f.param_types[0]) |PT| break :find PT;
                    }
                    break :find null;
                };
                const arg0_target_type: ?type = find: {
                    const Arg0 = arg0_type orelse break :find null;
                    switch (@typeInfo(Arg0)) {
                        .pointer => |pt| if (pt.size == .one) break :find pt.child,
                        else => {},
                    }
                    break :find null;
                };
                if (arg0_target_type) |New| {
                    if (S) |Current| {
                        if (New != Current) @compileError("Multiple static type detected: " ++ @typeName(Current) ++ ", " ++ @typeName(New));
                    } else {
                        S = New;
                    }
                }
            }
        }
    }
    return S orelse void;
}
/// Different custom types.
pub const custom = opaque {
    pub const Type = enum { module, class, @"enum", object, iterator };
};
/// Return type if the type given is a custom type.
pub fn isCustomType(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .@"struct" => @hasDecl(T, "custom_type") and @TypeOf(T.custom_type) == custom.Type,
        else => false,
    };
}
/// Return true if the given type can be transform to a custom class.
pub fn canBeCustomClass(comptime T: type) bool {
    Validator(T, .class, .{ .comptime_error = false }).check() catch return false;
    return true;
}
/// Types of validation.
pub const Validation = enum { module, class, @"enum" };
/// API Validator.
pub fn Validator(comptime T: type, comptime kind: Validation, comptime options: struct {
    comptime_error: bool = true,
}) type {
    return struct {
        pub fn check() !void {
            try checkContainer();
            try checkGetters();
            try checkSetters();
            try checkMethods();
            switch (kind) {
                .module => {
                    try checkHandlers(module_prototypes);
                },
                .class => {
                    try checkHandlers(object_prototypes);
                    try checkStaticGetters();
                    try checkStaticSetters();
                    try checkStaticMethods();
                    try checkStaticHandlers(class_prototypes);

                    if (@hasDecl(T, "initSelf")) {
                        try checkInitSelf();
                    } else if (@hasDecl(T, "init")) {
                        try checkInit();
                    }
                    if (@hasDecl(T, "deinit")) {
                        try checkDeinit();
                    }
                },
                .@"enum" => {
                    try checkStaticGetters();
                    try checkStaticSetters();
                    try checkStaticMethods();
                },
            }
        }

        fn checkContainer() !void {
            switch (kind) {
                .module, .class => {
                    if (@typeInfo(T) != .@"struct") {
                        report("Struct expected, received: " ++ @typeName(T));
                        return error.NotStruct;
                    }
                },
                .@"enum" => {
                    if (@typeInfo(T) != .@"enum") {
                        report("Enum expected, received: " ++ @typeName(T));
                        return error.NotEnum;
                    }
                },
            }
        }

        fn checkGetters() !void {
            @setEvalBranchQuota(2000000);
            for (std.meta.declarations(T)) |decl_name| {
                if (std.mem.startsWith(u8, decl_name, "get ")) {
                    if (kind == .@"enum") {
                        report("Enums cannot have getters");
                        return error.Unsuppported;
                    }
                    const Handler = @TypeOf(@field(T, decl_name));
                    checkGetter(T, Handler) catch |err| {
                        const err_msg = decamelize(@errorName(err));
                        report(err_msg ++ ": " ++ fnName(decl_name) ++ " is not a valid getter");
                        return err;
                    };
                }
            }
        }

        fn checkGetter(comptime Self: type, comptime FT: type) !void {
            const fi = @typeInfo(FT).@"fn";
            if (fi.param_types.len != 1) return error.IncorrectArgumentCount;
            try checkSelf(Self, fi.param_types[0] orelse return);
        }

        fn checkSetters() !void {
            @setEvalBranchQuota(2000000);
            for (std.meta.declarations(T)) |decl_name| {
                if (std.mem.startsWith(u8, decl_name, "set ")) {
                    if (kind == .@"enum") {
                        report("Enums cannot have setters");
                        return error.Unsuppported;
                    }
                    const Handler = @TypeOf(@field(T, decl_name));
                    checkSetter(T, Handler) catch |err| {
                        const err_msg = decamelize(@errorName(err));
                        report(err_msg ++ ": " ++ fnName(decl_name) ++ " is not a valid setter");
                        return err;
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

        fn checkMethods() !void {
            @setEvalBranchQuota(2000000);
            for (std.meta.declarations(T)) |decl_name| {
                if (std.mem.startsWith(u8, decl_name, "call ")) {
                    const Handler = @TypeOf(@field(T, decl_name));
                    checkMethod(T, Handler) catch |err| {
                        const err_msg = decamelize(@errorName(err));
                        report(err_msg ++ ": " ++ fnName(decl_name) ++ " is not a valid method");
                        return err;
                    };
                }
            }
        }

        fn checkMethod(comptime Self: type, comptime FT: type) !void {
            const fi = @typeInfo(FT).@"fn";
            switch (fi.param_types.len) {
                1, 2, 3 => |count| {
                    const Arg0 = fi.param_types[0] orelse return;
                    try checkSelf(Self, Arg0);
                    if (count == 2) {
                        const Arg1 = fi.param_types[1] orelse return;
                        if (@typeInfo(Arg1) != .@"struct") return error.ArgumentIsNotStruct;
                    } else if (count == 3) {
                        const Arg1 = fi.param_types[1] orelse return;
                        const Arg2 = fi.param_types[1] orelse return;
                        if (Arg1 != std.mem.Allocator) return error.ArgumentIsNotAllocator;
                        if (@typeInfo(Arg2) != .@"struct") return error.ArgumentIsNotStruct;
                    }
                },
                else => return error.IncorrectArgumentCount,
            }
        }

        fn checkHandlers(comptime prototypes: anytype) !void {
            @setEvalBranchQuota(2000000);
            for (std.meta.declarations(T)) |decl_name| {
                const MP = @TypeOf(prototypes);
                if (@hasField(MP, decl_name)) {
                    const prototype = @field(prototypes, decl_name);
                    const Handler = @TypeOf(@field(T, decl_name));
                    checkHandler(T, Handler, prototype) catch |err| {
                        const err_msg = decamelize(@errorName(err));
                        const p_name = prototypeName(prototype);
                        report(err_msg ++ ": " ++ fnName(decl_name) ++ " should be " ++ p_name);
                        return err;
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

        fn checkStaticGetters() !void {
            @setEvalBranchQuota(2000000);
            for (std.meta.declarations(T)) |decl_name| {
                if (std.mem.startsWith(u8, decl_name, "static get ")) {
                    report("PHP currently does not support dynamic static setters/getters");
                    return error.Unsuppported;
                }
            }
        }

        fn checkStaticSetters() !void {
            @setEvalBranchQuota(2000000);
            for (std.meta.declarations(T)) |decl_name| {
                if (std.mem.startsWith(u8, decl_name, "static set ")) {
                    report("PHP currently does not support dynamic static setters/getters");
                    return error.Unsuppported;
                }
            }
        }

        fn checkStaticMethods() !void {
            @setEvalBranchQuota(2000000);
            const S = FindStatic(T);
            for (std.meta.declarations(T)) |decl_name| {
                if (std.mem.startsWith(u8, decl_name, "static call ")) {
                    const Handler = @TypeOf(@field(T, decl_name));
                    checkMethod(S, Handler) catch |err| {
                        const err_msg = decamelize(@errorName(err));
                        report(err_msg ++ ": " ++ fnName(decl_name) ++ " is not a valid static method");
                        return err;
                    };
                }
            }
        }

        fn checkStaticHandlers(comptime prototypes: anytype) !void {
            @setEvalBranchQuota(2000000);
            const S = FindStatic(T);
            for (std.meta.declarations(T)) |decl_name| {
                const MP = @TypeOf(prototypes);
                if (@hasField(MP, decl_name)) {
                    const prototype = @field(prototypes, decl_name);
                    const Handler = @TypeOf(@field(T, decl_name));
                    checkHandler(S, Handler, prototype) catch |err| {
                        const err_msg = decamelize(@errorName(err));
                        const p_name = prototypeName(prototype);
                        report(err_msg ++ ": " ++ fnName(decl_name) ++ " should be " ++ p_name);
                        return err;
                    };
                }
            }
        }

        fn checkInitSelf() !void {
            const InitSelf = @TypeOf(T.initSelf);
            const arg_count = argCount(InitSelf);
            const Arg0 = switch (arg_count) {
                1 => struct {},
                2 => php.util.ArgType(InitSelf, 1),
                else => void,
            };
            if (@typeInfo(Arg0) != .@"struct") {
                report("initSelf() should accept a single struct as its sole argument");
                return error.InvalidInitArgument;
            }
        }

        fn checkInit() !void {
            const Init = @TypeOf(T.init);
            const arg_count = argCount(Init);
            const Arg0 = switch (arg_count) {
                0 => struct {},
                1 => ArgType(Init, 0),
                else => void,
            };
            if (@typeInfo(Arg0) != .@"struct") {
                report("init() should accept a single struct as its sole argument");
                return error.InvalidInitArgument;
            }
        }

        fn checkDeinit() !void {
            const Deinit = @TypeOf(T.deinit);
            const arg_count = argCount(Deinit);
            const Arg0 = switch (arg_count) {
                0 => void,
                else => ArgType(Deinit, 0),
            };
            if (@typeInfo(Arg0) != .pointer or @typeInfo(Arg0).pointer.child != T) {
                report("deinit() should accept a self pointer");
                return error.InvalidDeinitArgument;
            }
            if (arg_count > 1) {
                report("deinit() should accept no argument");
                return error.InvalidDeinitArgument;
            }
            if (ReturnType(Deinit) != void) {
                report("deinit() should return void");
                return error.InvalidDeinitReturnValue;
            }
        }

        fn checkSelf(comptime Self: type, comptime AT: type) !void {
            switch (@typeInfo(AT)) {
                .pointer => |pt| if (pt.child != Self) return error.IncorrectSelfArgument,
                .@"enum" => if (AT != Self) return error.IncorrectSelfArgument,
                else => return error.IncorrectSelfArgument,
            }
        }

        fn report(msg: []const u8) switch (options.comptime_error) {
            true => noreturn,
            false => void,
        } {
            if (options.comptime_error) @compileError(msg);
        }
    };
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
