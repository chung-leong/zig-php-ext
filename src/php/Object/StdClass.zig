const php = @import("../root.zig");
const Array = php.Array;
const Object = php.Object;
const Value = php.Value;

pub fn object(self: *const @This()) *Object {
    return @constCast(&self.object_instance);
}

pub fn createFromAny(arg: anytype, options: Value.ConversionOptions) *@This() {
    const T = @TypeOf(arg);
    // allow tuples to be converted eventhough Array makes more sense
    if (@typeInfo(T) != .@"struct") @compileError("Struct expected, received: " ++ @typeName(T));
    const arr: *Array = .createFromAny(arg, options);
    const obj: *Object = .createStandard();
    obj.impl.properties = @ptrCast(arr);
    return @ptrCast(obj);
}

object_instance: Object,
