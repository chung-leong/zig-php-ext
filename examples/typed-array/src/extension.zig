const std = @import("std");

const ArrayBuffer = @import("ArrayBuffer.zig");
const php = @import("php/root.zig");
const TypedArray = @import("TypedArray.zig").@"fn";

pub const @"export ArrayBuffer" = php.Class.Custom(ArrayBuffer);

pub const @"export Int8Array" = php.Class.Custom(TypedArray(i8, .{}));
pub const @"export Uint8Array" = php.Class.Custom(TypedArray(u8, .{}));
pub const @"export Int16Array" = php.Class.Custom(TypedArray(i16, .{}));
pub const @"export Uint16Array" = php.Class.Custom(TypedArray(u16, .{}));
pub const @"export Int32Array" = php.Class.Custom(TypedArray(i32, .{}));
pub const @"export Uint32Array" = php.Class.Custom(TypedArray(u32, .{}));
pub const @"export Int64Array" = php.Class.Custom(TypedArray(i64, .{}));
pub const @"export Uint64Array" = php.Class.Custom(TypedArray(u64, .{}));

pub const @"export Uint8ClampedArray" = php.Class.Custom(TypedArray(u8, .{ .clamped = true }));

pub const @"export Float16Array" = php.Class.Custom(TypedArray(f16, .{}));
pub const @"export Float32Array" = php.Class.Custom(TypedArray(f32, .{}));
pub const @"export Float64Array" = php.Class.Custom(TypedArray(f64, .{}));
