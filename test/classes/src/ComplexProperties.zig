const php = @import("php/root.zig");
const getter = php.Object.getter;
const setter = php.Object.setter;

const Child = struct {
    pub const @"get number" = getter(@This(), .number);
    pub const @"set number" = setter(@This(), .number);

    number: i32 = 1,
};

pub fn init() !@This() {
    const child = try php.Object.allocator.create(Child);
    child.* = .{};
    return .{
        .string = .create(""),
        .array = .create(),
        .object = .createStandard(),
        .child = child,
    };
}

pub fn deinit(self: *@This()) void {
    self.string.release();
    self.array.release();
    self.object.release();
    php.Object.fromCustom(self.child).release();
}

pub const @"export Child" = php.Class.Custom(Child);

pub const @"get string" = getter(@This(), .string);
pub const @"set string" = setter(@This(), .string);

pub const @"get array" = getter(@This(), .array);
pub const @"set array" = setter(@This(), .array);

pub const @"get object" = getter(@This(), .object);
pub const @"set object" = setter(@This(), .object);

pub const @"get child" = getter(@This(), .child);
pub const @"set child" = setter(@This(), .child);

string: *php.String,
array: *php.Array,
object: *php.Object,
child: *Child,
