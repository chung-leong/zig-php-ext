const std = @import("std");

const php = @import("php/root.zig");
const getter = php.Object.getter;
const setter = php.Object.setter;

const Child = struct {
    pub const @"get number" = getter(@This(), .number);
    pub const @"set number" = setter(@This(), .number);

    number: i32 = 1,
};

pub fn init() !@This() {
    return .{
        .string = .create(""),
        .strings = init: {
            const strings = try php.allocator.alloc(*php.String, 2);
            strings[0] = .create("A");
            strings[1] = .create("B");
            break :init strings;
        },
        .array = .create(),
        .object = .createStandard(),
        .child = init: {
            const child = try php.Object.allocator.create(Child);
            child.* = .{};
            break :init child;
        },
        .children = init: {
            const children = try php.allocator.alloc(*Child, 3);
            for (children, 0..) |*ptr, i| {
                const new_child = try php.Object.allocator.create(Child);
                new_child.* = .{ .number = @intCast(100 + i) };
                ptr.* = new_child;
            }
            break :init children;
        },
    };
}

pub fn deinit(self: *@This()) void {
    self.string.release();
    for (self.strings) |str| str.release();
    php.allocator.free(self.strings);
    self.array.release();
    self.object.release();
    php.Object.fromCustom(self.child).release();
    for (self.children) |child| php.Object.fromCustom(child).release();
    php.allocator.free(self.children);
}

pub const @"export Child" = php.Class.Custom(Child);

pub const @"get string" = getter(@This(), .string);
pub const @"set string" = setter(@This(), .string);

pub const @"get strings" = getter(@This(), .strings);
pub const @"set strings" = setter(@This(), .strings);

pub const @"get array" = getter(@This(), .array);
pub const @"set array" = setter(@This(), .array);

pub const @"get object" = getter(@This(), .object);
pub const @"set object" = setter(@This(), .object);

pub const @"get child" = getter(@This(), .child);
pub const @"set child" = setter(@This(), .child);

pub const @"get children" = getter(@This(), .children);
pub const @"set children" = setter(@This(), .children);

string: *php.String,
strings: []*php.String,
array: *php.Array,
object: *php.Object,
child: *Child,
children: []*Child,
