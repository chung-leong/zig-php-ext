const std = @import("std");

const php = @import("php/root.zig");
const getter = php.IniEntry.getter;
const setter = php.IniEntry.setter;

pub fn moduleStartup(_: *@This(), module_type: php.Module.Type, module_no: c_int) !void {
    _ = module_no;
    php.print("moduleStartup: {}\n", .{module_type});
}

pub fn moduleShutdown(_: *@This(), module_type: php.Module.Type, module_no: c_int) !void {
    _ = module_no;
    php.print("moduleShutdown: {}\n", .{module_type});
}

pub fn requestStartup(_: *@This(), module_type: php.Module.Type, module_no: c_int) !void {
    _ = module_no;
    php.print("requestStartup: {}\n", .{module_type});
}

pub fn requestShutdown(_: *@This(), module_type: php.Module.Type, module_no: c_int) !void {
    _ = module_no;
    php.print("requestShutdown: {}\n", .{module_type});
}

pub fn infoRequest(_: *@This(), module: *php.Module) !void {
    var table: php.InfoTable = .init();
    table.addTwoHeaders("Column A", "Column B");
    table.addTwoColumns("aaaaaaaa", "bbbbbbbb");
    table.end();
    module.displayIniEntries();
}

const Flags = packed struct {
    option_a: bool = true,
    option_b: bool = false,
    option_c: bool = true,
};
const Pet = enum { cat, dog, monkey, hippopotamus };

pub const @"export module_x\\Flags" = Flags;
pub const @"export module_x\\Pet" = Pet;

pub const @"get string" = getter(@This(), .string);
pub const @"set string" = setter(@This(), .string);

pub const @"get integer" = getter(@This(), .integer);
pub const @"set integer" = setter(@This(), .integer);

pub const @"get boolean" = getter(@This(), .boolean);
pub const @"set boolean" = setter(@This(), .boolean);

pub const @"get pet" = getter(@This(), .pet);
pub const @"set pet" = setter(@This(), .pet);

pub const @"get flags" = getter(@This(), .flags);
pub const @"set flags" = setter(@This(), .flags);

string: [:0]const u8 = "Hello world",
integer: i32 = 1234,
float: f64 = 0.1234,
boolean: bool = false,
pet: Pet = .hippopotamus,
flags: Flags = .{},
