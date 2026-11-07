const std = @import("std");

const php = @import("root.zig");
const php_al = php.allocator;
const c = php.c;
const pi = php.imports;
const decamelizeAlloc = php.util.decamelizeAlloc;
const WithoutError = php.util.WithoutError;

const oom_msg: [:0]const u8 = "out of memory";
threadlocal var error_message: ?[:0]const u8 = null;

/// Format a string and save it as the last reported error message.
pub fn report(comptime fmt: []const u8, params: anytype) @TypeOf(error.FailureReported) {
    if (error_message) |msg| freeMessage(msg);
    error_message = php_al.printSentinel(fmt, params, 0) catch oom_msg;
    return error.FailureReported;
}
/// Return true when there is a pending error message.
pub fn hasMessage() bool {
    return error_message != null;
}
/// Free the message sent earlier by `report`.
pub fn clearMessage() void {
    if (error_message) |msg| {
        freeMessage(msg);
        error_message = null;
    }
}
/// Return the message associated with the last reported failure. Generate a synthetic one from
/// the error name when a message wasn't given.
pub fn acquireMessage(err: anytype) [:0]const u8 {
    if (error_message) |msg| {
        error_message = null;
        return msg;
    }
    return decamelizeAlloc(php_al, @errorName(err)) catch oom_msg;
}
/// Free memory used by string returned by `acquireMessage`.
pub fn freeMessage(msg: []const u8) void {
    if (msg.ptr != oom_msg.ptr) php_al.free(msg);
}
/// Check if the given error is the specified one. Return false if the specified error is not
/// possible (i.e. outside the set of `err`.
pub fn match(err: anytype, other_err: anytype) bool {
    const E1 = @TypeOf(err) || error{};
    const E2 = @TypeOf(other_err);
    return if (E1 || E2 == E1) err == other_err else false;
}
/// Throw an exception containing either a message set earlier by `report` or a message
/// automatically generated from by the error name.
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
/// Issue a warning, using a message set earlier by `report` or an automatic message generated
/// from the error name.
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
/// Send information concerning reported failure to stderr.
pub fn show(err: anytype) void {
    if (match(err, error.ExceptionThrown)) return;
    const msg = acquireMessage(err);
    defer freeMessage(msg);
    std.debug.print("Failure: {s}\n", .{msg});
}
/// Trigger an error at comptime when a type isn't supported.
pub fn unsupported(comptime T: type) noreturn {
    @compileError("Unexpected type: " ++ @typeName(T));
}

/// Text that goes in front of every exception message.
pub var exception_prefix: [:0]const u8 = "";
/// Text that comes after every exception message.
pub var exception_suffix: [:0]const u8 = "";

fn withSentinel(str: []const u8) [:0]const u8 {
    const array = init: {
        var buffer: [str.len + 1]u8 = undefined;
        @memcpy(buffer[0..str.len], str);
        buffer[str.len] = 0;
        break :init buffer;
    };
    return @ptrCast(&array);
}
