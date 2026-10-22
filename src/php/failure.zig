const std = @import("std");

const php = @import("root.zig");
const php_al = php.allocator;
const c = php.c;
const pi = php.imports;
const decamelize = php.util.decamelize;
const WithoutError = php.util.WithoutError;

pub fn report(comptime fmt: []const u8, params: anytype) error{FailureReported} {
    if (error_message) |msg| freeMessage(msg);
    error_message = std.fmt.allocPrintSentinel(php_al, fmt, params, 0) catch oom_msg;
    return error.FailureReported;
}

const oom_msg = "out of memory";
threadlocal var error_message: ?[]const u8 = null;

pub fn hasMessage() bool {
    return error_message != null;
}

pub fn clearMessage() void {
    if (error_message) |msg| {
        freeMessage(msg);
        error_message = null;
    }
}

pub fn acquireMessage(err: anytype) []const u8 {
    if (error_message) |msg| {
        error_message = null;
        return msg;
    }
    const text = errorMessage(err);
    return php_al.dupe(u8, text) catch oom_msg;
}

pub fn freeMessage(msg: []const u8) void {
    if (msg.ptr != oom_msg.ptr) php_al.free(msg);
}

pub fn errorMessage(err: anytype) [:0]const u8 {
    @setEvalBranchQuota(2000000);
    return switch (err) {
        inline else => |possible_error| comptime decamelize(@errorName(possible_error)),
    };
}

pub fn match(err: anytype, other_err: anytype) bool {
    const E1 = @TypeOf(err) || error{};
    const E2 = @TypeOf(other_err);
    return if (E1 || E2 == E1) err == other_err else false;
}

pub fn throw(err: anytype) void {
    // if an exception has already been thrown then don't do anything
    if (match(err, error.ExceptionThrown)) return;
    const msg = acquireMessage(err);
    defer freeMessage(msg);
    _ = pi.zend_throw_exception_ex(
        null,
        0,
        "%s%s%s",
        exception_prefix.ptr,
        msg.ptr,
        exception_suffix.ptr,
    );
}

pub fn warn(err: anytype) void {
    if (match(err, error.ExceptionThrown)) return;
    const msg = acquireMessage(err);
    defer freeMessage(msg);
    pi.zend_error(
        c.E_WARNING,
        "%s%s%s",
        exception_prefix.ptr,
        msg.ptr,
        exception_suffix.ptr,
    );
}

pub fn show(err: anytype) void {
    if (match(err, error.ExceptionThrown)) return;
    const msg = acquireMessage(err);
    defer freeMessage(msg);
    std.debug.print("Failure: {s}\n", .{msg});
}

pub fn unsupported(comptime T: type) noreturn {
    @compileError("Unexpected type: " ++ @typeName(T));
}

pub var exception_prefix: [:0]const u8 = "";
pub var exception_suffix: [:0]const u8 = "";
