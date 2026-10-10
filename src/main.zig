const std = @import("std");
const options = @import("options");

const php = @import("php/root.zig");
const Module = php.Module;

var module: Module.Custom(@import("extension.zig"), .{
    // app name and version are extract from composer.json by build.zig
    .name = options.app_name,
    .version = options.app_version,
}) = .init();
comptime {
    module.register();
}

pub fn DllMain(
    _: std.os.windows.HINSTANCE,
    _: std.os.windows.DWORD,
    _: std.os.windows.LPVOID,
) std.os.windows.BOOL {
    return if (php.linkWindowsImports()) .TRUE else .FALSE;
}
