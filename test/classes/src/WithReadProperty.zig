const php = @import("php/root.zig");
const Object = php.Object;
const getter = Object.getter;
const setter = Object.setter;
const String = php.String;
const Value = php.Value;

pub const @"get number" = getter(@This(), .number);
pub const @"set number" = setter(@This(), .number);

pub const @"get optional" = getter(@This(), .optional);
pub const @"set optional" = setter(@This(), .optional);

pub fn readProperty(self: *@This(), name: *String, access: Value.Access) !Value {
    php.print("(readProperty: {s}) ", .{name.slice()});
    return if (name.matchSlice("foo"))
        .fromInteger(self.number)
    else if (name.matchSlice("bar"))
        .fromString(.create("Rats live on no evil star"))
    else if (access == .isset)
        .fromNull()
    else
        error.Undefined;
}

pub fn writeProperty(self: *@This(), name: *String, value: Value) !void {
    php.print("(writeProperty: {s})\n", .{name.slice()});
    if (name.matchSlice("foo"))
        self.number = @intCast(try value.getInteger())
    else if (name.matchSlice("bar"))
        return error.ReadOnly
    else
        return error.Undefined;
}

pub fn hasProperty(_: *@This(), name: *String) !bool {
    php.print("(hasProperty: {s}) ", .{name.slice()});
    return if (name.matchSlice("foo"))
        true
    else if (name.matchSlice("bar"))
        true
    else
        false;
}

pub fn unsetProperty(self: *@This(), name: *String) !void {
    php.print("(unsetProperty: {s})\n", .{name.slice()});
    if (name.matchSlice("foo"))
        self.number = -1
    else if (name.matchSlice("bar"))
        return error.ReadOnly
    else
        return error.Undefined;
}

number: i32 = 2001,
optional: ?i32 = 789,
