const std = @import("std");
const builtin = @import("builtin");

pub const c = @import("c");
pub const major_version = c.PHP_MAJOR_VERSION;
pub const minor_version = c.PHP_MINOR_VERSION;
pub const api_no = c.ZEND_MODULE_API_NO;

pub const Allocator = @import("Allocator.zig");
pub const Array = @import("Array.zig");
pub const Callable = @import("Callable.zig");
pub const Class = @import("Class.zig");
pub const Constant = @import("Constant.zig");
pub const Dictionary = @import("Dictionary.zig").@"union";
pub const Enum = @import("Enum.zig");
pub const failure = @import("failure.zig");
pub const Function = @import("Function.zig");
pub const InfoTable = @import("InfoTable.zig");
pub const IniEntry = @import("IniEntry.zig");
pub const List = @import("List.zig").@"union";
pub const Module = @import("Module.zig");
pub const Object = @import("Object.zig");
pub const Reference = @import("Reference.zig");
pub const Resource = @import("Resource.zig");
pub const Singleton = @import("Singleton.zig").@"fn";
pub const Stream = @import("Stream.zig");
pub const String = @import("String.zig");
pub const util = @import("util.zig");
pub const Value = @import("Value.zig");

/// Build id of the version PHP the extensioned was compiled for.
pub const build_id = std.fmt.comptimePrint("API{d}{s}{s}{s}{s}", .{
    c.ZEND_MODULE_API_NO,
    c.ZEND_BUILD_TS,
    c.ZEND_BUILD_DEBUG,
    c.ZEND_BUILD_SYSTEM,
    c.ZEND_BUILD_EXTRA,
});
/// Boolean indicating whether debug features are active (ZEND_DEBUG = 1).
pub const debug = c.ZEND_DEBUG != 0;
/// Boolean indicating whether PHP is compiled for a multithreaded environment (ZTS = 1).
pub const use_tsrm = @hasDecl(c, "ZTS");
/// Allocator that obtains memory from PHP's memory manager.
pub const allocator: std.mem.Allocator = .{ .ptr = undefined, .vtable = &Allocator.vtable };
/// Namespace of functions imported from PHP. On Windows, the symbols are pointers due to the use
/// of late binding. You have to use deref() to deference pointers to data.
pub const imports = switch (builtin.target.os.tag) {
    // on Windows, we link symbols in PHP DLL manually
    .windows => @import("win32-imports.zig"),
    else => c,
};
/// Initiate the dynamic linking process on Windows.
pub const linkWindowsImports = switch (builtin.target.os.tag) {
    .windows => imports.link,
    else => {},
};
/// Dereference a pointer on Windows. On other platform, the function simply returns the argument.
pub inline fn deref(arg: anytype) switch (builtin.target.os.tag) {
    .windows => @TypeOf(arg.*),
    else => @TypeOf(arg),
} {
    return switch (builtin.target.os.tag) {
        .windows => arg.*,
        else => arg,
    };
}
/// Return a pointer to one of PHP's globals. `name` can be "compiler", "executor", etc.
pub inline fn globals(comptime name: []const u8) *@field(c, "zend_" ++ name ++ "_globals") {
    if (use_tsrm) {
        const cache_address = @intFromPtr(imports.tsrm_get_ls_cache());
        const offset = deref(@field(imports, name ++ "_globals_offset"));
        return @ptrFromInt(cache_address + offset);
    } else {
        return @constCast(deref(&@field(imports, name ++ "_globals")));
    }
}
/// Return the global constant table.
pub fn constants() *Array {
    const eg = globals("executor");
    return @ptrCast(eg.zend_constants);
}
/// Throw an exception object.
pub fn throwException(obj: *Object) error{ExceptionThrown} {
    const value: Value = .fromObject(obj);
    imports.zend_throw_exception_object(@ptrCast(@constCast(&value)));
    return error.ExceptionThrown;
}
/// Check if an exception has been thrown.
pub fn exceptionThrown() bool {
    const eg = globals("executor");
    return eg.exception != null;
}
/// Write bytes to PHP's output stream (php://output).
pub fn write(bytes: []const u8) !usize {
    const written = imports.php_write(@ptrCast(@constCast(bytes.ptr)), bytes.len);
    if (written < 0) return error.Failed;
    return @intCast(written);
}
/// Format a string using std.fmt.bufPrint() and send the result to PHP's output stream. Fall back to std.fmt.print() if the resulting string is too long for the fixed buffer.
pub fn print(comptime fmt: []const u8, args: anytype) void {
    var buffer: [1024]u8 = undefined;
    if (std.fmt.bufPrint(&buffer, fmt, args)) |str| {
        _ = write(str) catch {};
    } else |_| {
        const str = allocator.print(fmt, args) catch unreachable;
        defer allocator.free(str);
        _ = write(str) catch {};
    }
}
/// Flush PHP's output stream.
pub fn flush() void {
    _ = imports.php_output_flush();
}
