const std = @import("std");

const php = @import("php/root.zig");
const Array = php.Array;
const Module = php.Module;
const Value = php.Value;

pub fn @"call printBool"(_: *@This(), args: struct {
    boolean: bool,
}) !void {
    php.print("boolean = {}\n", .{args.boolean});
}

pub fn @"call printInt"(_: *@This(), args: struct {
    int: i32,
}) !void {
    php.print("int = {d}\n", .{args.int});
}

pub fn @"call printUint"(_: *@This(), args: struct {
    uint: u32,
}) !void {
    php.print("uint = {d}\n", .{args.uint});
}

pub fn @"call printIntFloats"(_: *@This(), args: struct {
    int: i32,
    float1: f32,
    float2: f64 = 8.88,
}) !void {
    php.print("int = {d}, float1 = {d}, float2 = {d}\n", .{ args.int, args.float1, args.float2 });
}

pub fn @"call printString"(_: *@This(), args: struct {
    string: []const u8 = "Dingo ate my baby!",
}) void {
    php.print("string = {s}\n", .{args.string});
}

pub fn @"call printStrings"(_: *@This(), args: struct {
    string1: []const u8,
    string2: []const u8 = "cow",
}) void {
    php.print("string1 = {s}, string2 = {s}\n", .{ args.string1, args.string2 });
}

pub fn @"call printEnum"(_: *@This(), args: struct {
    animal: enum { cat, dog, monkey },
}) void {
    php.print("enum = {}\n", .{args.animal});
}

pub fn @"call printFlags"(_: *@This(), args: struct {
    flags: packed struct(u8) {
        option1: bool = false,
        option2: bool = false,
        option3: bool = false,
        option4: bool = false,
        _: u4 = 0,
    },
}) void {
    php.print("flags = {}\n", .{args.flags});
}

pub fn @"call printStringList"(_: *@This(), args: struct {
    list: [][]const u8,
}) void {
    for (args.list, 0..) |item, i| {
        php.print("{d}: {s}\n", .{ i, item });
    }
}

pub fn @"call printStruct"(_: *@This(), args: struct {
    data: struct {
        list: []const []const u8 = &.{ "hello", "world" },
        number: f64,
    },
}) void {
    php.print("number = {d}\n", .{args.data.number});
    for (args.data.list, 0..) |item, i| {
        php.print("{d}: {s}\n", .{ i, item });
    }
}

pub fn @"call printUnion"(_: *@This(), args: struct {
    input: union(enum) {
        string: []const u8,
        number: f64,
    },
}) void {
    switch (args.input) {
        .string => |str| php.print("string = {s}\n", .{str}),
        .number => |num| php.print("number = {d}\n", .{num}),
    }
}

pub fn @"call printArray"(_: *@This(), args: struct {
    array: [3]f64,
}) void {
    php.print("array = {any}\n", .{args.array});
}

pub fn @"call printVector"(_: *@This(), args: struct {
    vector: @Vector(3, f64),
}) void {
    php.print("vector = {d}\n", .{args.vector});
}

pub fn @"call setStrings"(
    _: *@This(),
    args: struct {
        value_ptr: *Value,
        optional_value_ptr: ?*Value,
    },
) void {
    args.value_ptr.replace(.fromString(.static("Hello world")));
    if (args.optional_value_ptr) |ptr| {
        ptr.replace(.fromString(.create("This is a test")));
    }
}

pub fn @"call acceptMany"(
    _: *@This(),
    args: struct {
        arg1: c_long,
        @"...": []const Value,
    },
) void {
    php.print("arg1 = {d}\n", .{args.arg1});
    php.print("extra = {d}\n", .{args.@"...".len});
    for (args.@"...", 0..) |arg, i| {
        const str = arg.cast(.string).string();
        defer str.release();
        php.print("{d} = {s}\n", .{ i, str.slice() });
    }
}

pub fn @"call acceptManyNamed"(
    _: *@This(),
    args: struct {
        arg1: c_long,
        @"...": []const Value,
        @"???": ?*Array,
    },
) void {
    php.print("arg1 = {d}\n", .{args.arg1});
    php.print("extra = {d}\n", .{args.@"...".len});
    for (args.@"...", 0..) |arg, i| {
        const str = arg.cast(.string).string();
        defer str.release();
        php.print("{d} = {s}\n", .{ i, str.slice() });
    }
    if (args.@"???") |named| {
        var iter = named.iterate(.{});
        while (iter.next()) |arg| {
            const name = iter.key().string();
            const str = arg.cast(.string).string();
            defer str.release();
            php.print("{s} = {s}\n", .{ name.slice(), str.slice() });
        }
    }
}

pub fn @"call acceptOptions"(
    _: *@This(),
    args: struct {
        arg1: c_long,
        options: struct {
            alpha: bool = false,
            beta: enum { cow, pig, chicken } = .pig,
        } = .{},
    },
) void {
    php.print("arg1 = {d}\n", .{args.arg1});
    php.print("options = {}\n", .{args.options});
}
