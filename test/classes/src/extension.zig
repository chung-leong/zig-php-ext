const std = @import("std");

const php = @import("php/root.zig");
const Class = php.Class;
const Module = php.Module;

pub const @"export Greeting" = Class.Custom(@import("Greeting.zig"));
pub const @"export Superhero" = Class.Custom(@import("Superhero.zig"));
pub const @"export Point" = Class.Custom(@import("Point.zig"));
pub const @"export ObjectList" = Class.Custom(@import("ObjectList.zig"));
