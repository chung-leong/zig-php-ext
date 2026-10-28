const std = @import("std");

const php = @import("../../root.zig");
const Array = php.Array;
const c = php.c;
const php_al = php.allocator;
const Callable = php.Callable;
const Class = php.Class;
const Dictionary = php.Dictionary;
const failure = php.failure;
const Function = php.Function;
const Arguments = Function.Arguments;
const unsupported = failure.unsupported;
const Object = php.Object;
const Resource = php.Resource;
const String = php.String;
const Value = php.Value;

pub fn init(args: *const Arguments) @This() {
    var info: c.arg_extra_info = undefined;
    c.get_argument_info(@ptrCast(args), &info);
    var len = info.len;
    const named = get: {
        if (info.extra) {
            // extra_named_params contains bogus values when it's not used
            if (args.getExtraNamed()) |arr| {
                len += 1;
                break :get arr.toValue();
            }
        }
        break :get null;
    };
    return .{
        .arg_ptr = @ptrCast(info.ptr),
        .len = len,
        .this = args.this(),
        .named_params = named,
        .callee = args.callee(),
    };
}

pub fn length(self: *const @This()) usize {
    return self.len;
}

pub fn hasNamed(self: *const @This()) bool {
    return self.named_params != null;
}

pub fn next(self: *@This()) ?Value {
    return if (self.peek(self.index)) |value| get: {
        self.index += 1;
        break :get value;
    } else null;
}

pub fn peek(self: *@This(), index: usize) ?Value {
    if (index < self.len) {
        // return named parameters as last argument
        if (index == self.len - 1) {
            if (self.named_params) |p| return p;
        }
        // return this pointer as first argument
        if (self.use_this_first and index == 0) return self.this;
        // return regular argument
        const offset: usize = if (self.use_this_first) 1 else 0;
        return self.arg_ptr[index - offset];
    } else {
        return null;
    }
}

pub fn remaining(self: *@This()) []const Value {
    const offset: usize = if (self.use_this_first) 1 else 0;
    const index = self.index;
    var len = self.len;
    if (self.named_params != null) len -= 1;
    self.index = self.len;
    return self.arg_ptr[index - offset .. len];
}

pub fn reset(self: *@This()) void {
    self.index = 0;
}

pub fn createArrayOf(self: *@This()) *Array {
    self.reset();
    const arr = Array.create();
    while (self.next()) |value| arr.append(value);
    return arr;
}

pub fn makeThisFirst(self: *@This()) !void {
    if (!self.use_this_first) {
        self.use_this_first = true;
        self.len += 1;
    }
}

pub fn extract(self: *@This(), comptime T: type) !T {
    std.debug.assert(self.index == 0);
    // make sure T is a struct/tuple
    if (@typeInfo(T) != .@"struct") @compileError("Struct type expected, received: " ++ @typeName(T));
    // check argument count
    const st = @typeInfo(T).@"struct";
    const min, const max = comptime init: {
        var required: usize = 0;
        var has_extra = false;
        var count: usize = 0;
        for (st.field_names, st.field_types, 0..) |arg_name, AT, i| {
            if (Function.isExtraArg(arg_name)) |variadic_type| {
                has_extra = true;
                switch (variadic_type) {
                    .named => if (AT != ?*Array) @compileError("Argument @\"???\" must be ?*Array"),
                    .unnamed => {
                        if (AT != []const Value) @compileError("Argument @\"...\" must be []const Value");
                        count = std.math.maxInt(usize);
                    },
                }
            } else {
                if (has_extra) @compileError("Named arguments must be ahead of @\"...\" and @\"???\": " ++ arg_name);
                if (!isFieldOptional(T, i)) required += 1;
                count += 1;
            }
        }
        break :init .{ required, count };
    };
    try self.verifyCount(min, max);
    var set: T = undefined;
    var mismatch: Mismatch = .{};
    defer mismatch.deinit();
    var required_remaining = min;
    inline for (st.field_names, 0..) |arg_name, i| {
        if (comptime Function.isExtraArg(arg_name)) |variadic_type| {
            @field(set, arg_name) = switch (variadic_type) {
                .named => if (self.named_params) |np| np.array() else null,
                // need to duplicate the list because freeConverted() will free it
                .unnamed => php_al.dupe(Value, self.remaining()) catch unreachable,
            };
        } else {
            const FT = @TypeOf(@field(set, arg_name));
            const optional = comptime isFieldOptional(T, i);
            // take value for optional argument only when there're enough left to satistfy
            // remaining required ones
            if (!optional or i + required_remaining < self.len) {
                const arg = self.next().?;
                const value = arg.convertTo(FT) catch |err| report: {
                    // remember the first mismatch
                    mismatch.record(self.callee.name(), arg_name, i, FT, arg, err);
                    self.index -= 1;
                    // break out of for loop if argument is required
                    if (!optional) break;
                    break :report fieldDefaultValue(T, i);
                };
                @field(set, arg_name) = value;
                if (!optional) required_remaining -= 1;
            } else {
                @field(set, arg_name) = fieldDefaultValue(T, i);
            }
        }
    }
    if (mismatch.recorded) {
        // report the mismatch only if we've failed to reach the end
        if (self.index < self.len) return mismatch.report();
    }
    return set;
}

pub fn extractNamed(self: *@This(), comptime T: type) !T {
    // method should be called prior to actual iteration
    std.debug.assert(self.index == 0);
    // make sure T is a tuple
    const valid = switch (@typeInfo(T)) {
        .@"struct" => |st| !st.is_tuple,
        else => false,
    };
    if (!valid) @compileError("Struct type expected, received: " ++ @typeName(T));
    var set: T = undefined;
    var mismatch: Mismatch = null;
    defer mismatch.deinit();
    inline for (@typeInfo(T).@"struct".field_names, 0..) |arg_name, i| {
        const FT = @TypeOf(@field(set, arg_name));
        const VT, const optional = switch (@typeInfo(FT)) {
            .optional => |opt| .{ opt.child, true },
            else => .{ FT, false },
        };
        const arg_maybe: ?*Value = get: {
            const args = self.named_params orelse break :get null;
            if (args.get(arg_name) catch null) |value| {
                args.delete(arg_name);
                break :get value;
            }
        };
        if (arg_maybe) |arg| {
            const value = arg.convertTo(VT) catch |err| {
                mismatch.record(self.callee.name(), arg_name, null, FT, arg, err);
                break;
            };
            @field(set, arg_name) = value;
        } else {
            if (optional) {
                @field(set, arg_name) = fieldDefaultValue(T, i);
            } else {
                mismatch.record(self.callee.name(), arg_name, null, FT, null, error.Missing);
                break;
            }
        }
    }
    if (mismatch.recorded) return mismatch.report();
    if (self.named_params) |args| {
        // if all named arguments were taken out, shrink the argument list
        if (args.length() == 0) {
            self.named_params = null;
            self.len -= 1;
        }
    }
    return set;
}

pub fn verifyCount(self: *const @This(), min: usize, max: usize) !void {
    if (self.len < min or self.len > max) {
        const desc, const count = if (max == min)
            .{ "exactly", min }
        else if (self.len > max)
            .{ "at most", max }
        else
            .{ "at least", min };
        return failure.report("{s}() expects {s} {d} argument{s}, {d} given{s}", .{
            self.callee.name().slice(),
            desc,
            count,
            if (count != 1) "s" else "",
            self.len,
            if (self.hasNamed()) " (the last being named arguments)" else "",
        });
    }
}

fn isFieldOptional(comptime T: type, comptime index: usize) bool {
    const st = @typeInfo(T).@"struct";
    const FT = st.field_types[index];
    return switch (@typeInfo(FT)) {
        .optional => true,
        else => st.field_attrs[index].default_value_ptr != null,
    };
}

fn fieldDefaultValue(comptime T: type, comptime index: usize) @typeInfo(T).@"struct".field_types[index] {
    const st = @typeInfo(T).@"struct";
    const FT = st.field_types[index];
    const field_attrs = st.field_attrs[index];
    const opaque_ptr = field_attrs.default_value_ptr orelse return null;
    const default_value_ptr: *const FT = @ptrCast(@alignCast(opaque_ptr));
    return default_value_ptr.*;
}

fn getTypeName(allocator: std.mem.Allocator, comptime T: type) []const u8 {
    @setEvalBranchQuota(2_000_000);
    return switch (@typeInfo(T)) {
        .bool => "boolean",
        .int => "int",
        .float => "float",
        .array, .vector => "array",
        .pointer => |pt| switch (pt.size) {
            .one => switch (pt.child) {
                String => "string",
                Array => "array",
                Object => "object",
                Resource => "resource",
                Value => "reference",
                else => switch (@typeInfo(pt.child)) {
                    .@"struct" => get: {
                        const custom_class = Class.Custom(pt.child).get();
                        const name = custom_class.name().slice();
                        break :get if (std.mem.lastIndexOfScalar(u8, name, '\\')) |slash_index|
                            name[slash_index + 1 ..]
                        else
                            name;
                    },
                    else => unsupported(T),
                },
            },
            .slice => switch (pt.child) {
                u8 => "string",
                else => "array",
            },
            else => unsupported(T),
        },
        .optional => |opt| std.fmt.allocPrint(allocator, "?{s}", .{
            getTypeName(allocator, opt.child),
        }) catch unreachable,
        .@"struct" => |st| switch (T) {
            Callable => "callable",
            else => switch (st.backing_integer != null) {
                true => "number|array|object",
                false => "array|object",
            },
        },
        .@"union" => |un| switch (T) {
            Dictionary => "array|object",
            else => format: {
                const len = un.field_types.len;
                var names: [len][]const u8 = undefined;
                inline for (un.field_types, 0..) |FT, i| {
                    const name = getTypeName(allocator, FT);
                    names[i] = name;
                }
                break :format std.mem.join(allocator, "|", &names) catch unreachable;
            },
        },
        .@"enum" => "number|string",
        else => unsupported(T),
    };
}

const Mismatch = struct {
    arena: std.heap.ArenaAllocator = undefined,
    recorded: bool = false,
    fn_name: ?*String = undefined,
    arg_name: []const u8 = undefined,
    value_type: []const u8 = undefined,
    index: ?usize = null,
    value: Value = undefined,
    err: anyerror = undefined,

    pub fn deinit(self: *@This()) void {
        if (self.recorded) {
            self.arena.deinit();
        }
    }

    pub fn record(self: *@This(), fn_name: *String, arg_name: []const u8, index: ?usize, comptime VT: type, value: ?Value, err: anyerror) void {
        if (!self.recorded) {
            self.arena = .init(php_al);
            self.recorded = true;
        }
        self.fn_name = fn_name;
        self.arg_name = arg_name;
        self.index = index;
        self.value = value orelse .fromNull();
        self.value_type = getTypeName(self.arena.allocator(), VT);
        self.err = err;
    }

    pub fn report(self: *@This()) error{FailureReported} {
        defer self.arena.deinit();
        const fn_name = if (self.fn_name) |n| n.slice() else "(unknown)";
        if (self.index) |index| {
            return switch (self.err) {
                error.NegativeValue => failure.report("{s}(): Argument #{d} ${s} must be a positive integer, received {d}", .{
                    fn_name,
                    index + 1,
                    self.arg_name,
                    self.value.getInteger() catch unreachable,
                }),
                else => failure.report("{s}(): Argument #{d} (${s}) must be of type {s}, {s} given", .{
                    fn_name,
                    index + 1,
                    self.arg_name,
                    self.value_type,
                    self.value.kind().name(),
                }),
            };
        } else {
            return switch (self.err) {
                error.NegativeValue => failure.report("{s}(): Named argument ${s} must be a positive integer, received {d}", .{
                    fn_name,
                    self.arg_name,
                    self.value.getInteger() catch unreachable,
                }),
                error.Missing => failure.report("{s}(): Named argument ${s} is required and expected to be of type {s}", .{
                    fn_name,
                    self.arg_name,
                    self.value_type,
                }),
                else => failure.report("{s}(): Named argument ${s} must be of type {s}, {s} given", .{
                    fn_name,
                    self.arg_name,
                    self.value_type,
                    self.value.kind().name(),
                }),
            };
        }
    }
};

arg_ptr: [*]Value,
this: Value,
use_this_first: bool = false,
named_params: ?Value,
len: usize,
index: usize = 0,
callee: *Function,
