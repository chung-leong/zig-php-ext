const std = @import("std");

const php = @import("php/root.zig");
const Class = php.Class;
const Module = php.Module;

pub const @"export Greeting" = Class.Custom(@import("Greeting.zig"));
pub const @"export Superhero" = Class.Custom(@import("Superhero.zig"));
pub const @"export Point" = Class.Custom(@import("Point.zig"));
pub const @"export ObjectList" = Class.Custom(@import("ObjectList.zig"));
pub const @"export WithStatic" = Class.Custom(@import("WithStatic.zig"));
pub const @"export WithFreeObject" = Class.Custom(@import("WithFreeObject.zig"));
pub const @"export WithGetConstructor" = Class.Custom(@import("WithGetConstructor.zig"));
pub const @"export WithCloneObject" = Class.Custom(@import("WithCloneObject.zig"));
pub const @"export WithClone" = Class.Custom(@import("WithClone.zig"));
