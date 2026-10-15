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
pub const @"export WithReadProperty" = Class.Custom(@import("WithReadProperty.zig"));
pub const @"export WithReadPropertyCache" = Class.Custom(@import("WithReadPropertyCache.zig"));
pub const @"export WithReadDimension" = Class.Custom(@import("WithReadDimension.zig"));
pub const @"export WithGetClassName" = Class.Custom(@import("WithGetClassName.zig"));
pub const @"export WithGetProperties" = Class.Custom(@import("WithGetProperties.zig"));
pub const @"export WithGetPropertiesNoGetters" = Class.Custom(@import("WithGetPropertiesNoGetters.zig"));
pub const @"export WithGetMethod" = Class.Custom(@import("WithGetMethod.zig"));
pub const @"export WithCompareWith" = Class.Custom(@import("WithCompareWith.zig"));
pub const @"export WithGetClosure" = Class.Custom(@import("WithGetClosure.zig"));
