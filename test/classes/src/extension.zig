const std = @import("std");

const php = @import("php/root.zig");
const Class = php.Class;
const Module = php.Module;
const getter = php.Object.getter;
const setter = php.Object.setter;

pub const @"export Greeting" = Class.Custom(@import("Greeting.zig"));
