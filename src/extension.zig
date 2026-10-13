const std = @import("std");

const php = @import("php/root.zig");
const InfoTable = php.InfoTable;
const Module = php.Module;
const getter = php.IniEntry.getter;
const setter = php.IniEntry.setter;

pub const @"export SOME_CONSTANT" = "Hello world";
pub const @"export SOME_ENUM" = enum { hello, world };

pub fn @"call greet"(self: *@This(), args: struct {
    name: []const u8,
}) !void {
    php.print("{s}, {s}!\n", .{ self.greeting, args.name });
}

pub const @"get greeting" = getter(@This(), .greeting);
pub const @"set greeting" = setter(@This(), .greeting);

pub fn moduleStartup(self: *@This(), module_type: Module.Type, module_no: c_int) !void {
    _ = self;
    _ = module_type;
    _ = module_no;
}

pub fn moduleShutdown(self: *@This(), module_type: Module.Type, module_no: c_int) void {
    _ = self;
    _ = module_type;
    _ = module_no;
}

pub fn requestStartup(self: *@This(), module_type: Module.Type, module_no: c_int) !void {
    _ = self;
    _ = module_type;
    _ = module_no;
}

pub fn requestShutdown(self: *@This(), module_type: Module.Type, module_no: c_int) void {
    _ = self;
    _ = module_type;
    _ = module_no;
}

pub fn infoRequest(self: *@This(), module: *Module) void {
    _ = self;
    var tbl: InfoTable = .init();
    tbl.addTwoColumns("Version", module.version());
    tbl.end();
    module.displayIniEntries();
}

greeting: [:0]const u8 = "Hello",
