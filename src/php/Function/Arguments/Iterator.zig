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
    const result = args.obtain();
    return .{
        .args = result.regular,
        .this = result.this.*,
        .named_params = result.named,
        .callee = args.callee(),
    };
}

pub fn length(self: *const @This()) usize {
    return self.args.len;
}

pub fn hasNamed(self: *const @This()) bool {
    return self.named_params != null;
}

pub fn next(self: *@This()) ?Value {
    const value = self.peek(self.index) orelse return null;
    self.index += 1;
    return value;
}

pub fn peek(self: *@This(), index: usize) ?Value {
    return if (index < self.args.len) self.args[index] else null;
}

pub fn remaining(self: *@This()) []const Value {
    defer self.index = self.args.len;
    return self.args[self.index..];
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

pub fn extract(self: *@This(), allocator: std.mem.Allocator, comptime T: type) !T {
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
    var required_remaining = min;
    inline for (st.field_names, st.field_types, 0..) |arg_name, FT, i| {
        if (comptime Function.isExtraArg(arg_name)) |variadic_type| {
            @field(set, arg_name) = switch (variadic_type) {
                .named => if (self.named_params) |np| np else null,
                .unnamed => self.remaining(),
            };
        } else {
            const optional = comptime isFieldOptional(T, i);
            // take value for optional argument only when there're enough left to satistfy
            // remaining required ones
            if (!optional or i + required_remaining < self.args.len) {
                const arg = self.next().?;
                const value = arg.extract(allocator, FT) catch |err| report: {
                    // remember the first mismatch
                    mismatch.record(self.callee.name(), arg_name, i, arg, err);
                    self.index -= 1;
                    // break out of for loop if argument is required
                    if (!optional) break;
                    break :report fieldDefaultValue(T, i);
                };
                @field(set, arg_name) = value;
                if (!optional) required_remaining -= 1;
            } else {
                const last = i == st.field_names.len - 1;
                @field(set, arg_name) = switch (last and self.hasNamed() and comptime isRegularStruct(FT)) {
                    // use named arguments to initialize the last argument
                    true => try self.extractNamed(allocator, FT),
                    false => fieldDefaultValue(T, i),
                };
            }
        }
    }
    if (mismatch.recorded) {
        // report the mismatch only if we've failed to reach the end
        if (self.index < self.args.len) return mismatch.report();
    }
    return set;
}

pub fn extractNamed(self: *@This(), allocator: std.mem.Allocator, comptime T: type) !T {
    if (comptime !isRegularStruct(T)) @compileError("Struct type expected, received: " ++ @typeName(T));
    var set: T = undefined;
    var mismatch: Mismatch = .{};
    const st = @typeInfo(T).@"struct";
    inline for (st.field_names, st.field_types, 0..) |arg_name, FT, i| {
        const VT, const optional = switch (@typeInfo(FT)) {
            .optional => |opt| .{ opt.child, true },
            else => .{ FT, false },
        };
        const arg_maybe: ?Value = get: {
            const args = self.named_params orelse break :get null;
            const name = String.static(arg_name);
            const value = args.get(name) catch break :get null;
            args.delete(name);
            break :get value;
        };
        if (arg_maybe) |arg| {
            const value = arg.extract(allocator, VT) catch |err| {
                mismatch.record(self.callee.name(), arg_name, null, arg, err);
                break;
            };
            @field(set, arg_name) = value;
        } else {
            if (optional) {
                @field(set, arg_name) = fieldDefaultValue(T, i);
            } else {
                mismatch.record(self.callee.name(), arg_name, null, null, error.Missing);
                break;
            }
        }
    }
    if (mismatch.recorded) return mismatch.report();
    return set;
}

pub fn verifyCount(self: *const @This(), min: usize, max: usize) !void {
    const len = self.args.len;
    if (len < min or len > max) {
        const desc, const count = if (max == min)
            .{ "exactly", min }
        else if (len > max)
            .{ "at most", max }
        else
            .{ "at least", min };
        return failure.report("{s}() expects {s} {d} argument{s}, {d} given{s}", .{
            self.callee.name().slice(),
            desc,
            count,
            if (count != 1) "s" else "",
            len,
            if (self.hasNamed()) " (the last being named arguments)" else "",
        });
    }
}

fn isRegularStruct(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .@"struct" => |st| !st.is_tuple,
        else => false,
    };
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

const Mismatch = struct {
    recorded: bool = false,
    fn_name: ?*String = undefined,
    arg_name: []const u8 = undefined,
    index: ?usize = null,
    value: Value = undefined,
    err: anyerror = undefined,

    pub fn record(self: *@This(), fn_name: *String, arg_name: []const u8, index: ?usize, value: ?Value, err: anyerror) void {
        self.recorded = true;
        self.fn_name = fn_name;
        self.arg_name = arg_name;
        self.index = index;
        self.value = value orelse .fromNull();
        self.err = err;
    }

    pub fn report(self: *@This()) error{FailureReported} {
        const fn_name = if (self.fn_name) |n| n.slice() else "(unknown)";
        const error_message = failure.acquireMessage(self.err);
        defer failure.freeMessage(error_message);
        if (self.index) |index| {
            return failure.report("{s}(): argument #{d} (${s}) is incorrect - {s}", .{
                fn_name,
                index + 1,
                self.arg_name,
                error_message,
            });
        } else {
            return failure.report("{s}(): named argument ${s} is incorrect: {s}", .{
                fn_name,
                self.arg_name,
                error_message,
            });
        }
    }
};

args: []Value,
this: Value,
named_params: ?*Array,
index: usize = 0,
callee: *Function,
