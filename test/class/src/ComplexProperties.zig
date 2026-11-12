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
            const child = php.Object.Custom(Child).create().custom();
            child.* = .{};
            break :init child;
        },
        .children = init: {
            const children = try php.allocator.alloc(*Child, 3);
            for (children, 0..) |*ptr, i| {
                const new_child = php.Object.Custom(Child).create().custom();
                new_child.* = .{ .number = @intCast(100 + i) };
                ptr.* = new_child;
            }
            break :init children;
        },
        .twins = init: {
            const child1 = php.Object.Custom(Child).create().custom();
            child1.* = .{ .number = 201 };
            const child2 = php.Object.Custom(Child).create().custom();
            child2.* = .{ .number = 202 };
            break :init .{ child1, child2 };
        },
        .friends = init: {
            const child1 = php.Object.Custom(Child).create().custom();
            child1.* = .{ .number = 41 };
            const child2 = php.Object.Custom(Child).create().custom();
            child2.* = .{ .number = 42 };
            break :init .{ .bob = child1, .jack = child2 };
        },
    };
}

// pub fn deinit(self: *@This()) void {
//     // self.string.release();
//     php.util.freeAny(self.string);
//     // for (self.strings) |str| str.release();
//     // php.allocator.free(self.strings);
//     php.util.freeAny(self.strings);
//     // self.array.release();
//     php.util.freeAny(self.array);
//     // self.object.release();
//     php.util.freeAny(self.object);
//     // php.Object.fromCustom(self.child).release();
//     php.util.freeAny(self.child);
//     // for (self.children) |child| php.Object.fromCustom(child).release();
//     // php.allocator.free(self.children);
//     php.util.freeAny(self.children);
//     // for (self.twins) |twin| php.Object.fromCustom(twin).release();
//     php.util.freeAny(self.twins);
//     // php.Object.fromCustom(self.friends.bob).release();
//     // php.Object.fromCustom(self.friends.jack).release();
//     php.util.freeAny(self.friends);
// }

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

pub const @"get twins" = getter(@This(), .twins);
pub const @"set twins" = setter(@This(), .twins);

pub const @"get friends" = getter(@This(), .friends);
pub const @"set friends" = setter(@This(), .friends);

string: *php.String,
strings: []*php.String,
array: *php.Array,
object: *php.Object,
child: *Child,
children: []*Child,
twins: [2]*Child,
friends: struct {
    bob: *Child,
    jack: *Child,
},
