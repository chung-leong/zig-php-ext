const std = @import("std");

const php = @import("php/root.zig");
const InfoTable = php.InfoTable;
const Module = php.Module;
const getter = php.util.getter;
const setter = php.util.setter;

pub fn @"call greet"(self: *@This(), args: struct {
    name: []const u8,
}) !void {
    php.print("{s}, {s}!\n", .{ self.greeting, args.name });
}

pub const @"get greeting" = getter(@This(), .greeting);
pub const @"set greeting" = setter(@This(), .greeting);

pub fn onModuleStartup(self: *@This(), module_type: Module.Type, module_no: c_int) !void {
    _ = self;
    _ = module_type;
    _ = module_no;
}

pub fn onModuleShutdown(self: *@This(), module_type: Module.Type, module_no: c_int) void {
    _ = self;
    _ = module_type;
    _ = module_no;
}

pub fn onRequestStartup(self: *@This(), module_type: Module.Type, module_no: c_int) !void {
    _ = self;
    _ = module_type;
    _ = module_no;
}

pub fn onRequestShutdown(self: *@This(), module_type: Module.Type, module_no: c_int) void {
    _ = self;
    _ = module_type;
    _ = module_no;
}

pub fn onInfoRequest(self: *@This(), module: *Module) void {
    _ = self;
    var tbl: InfoTable = .init();
    tbl.addTwoColumns("Version", module.version());
    tbl.end();
    module.displayIniEntries();
}

greeting: [:0]const u8 = "Hello",
