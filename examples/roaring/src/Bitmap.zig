const std = @import("std");

const zroaring = @import("zroaring");

const php = @import("php/root.zig");
const Object = php.Object;

pub fn init(args: struct { indices: []const u32 = &.{} }) !@This() {
    var bm: zroaring.Bitmap = .empty;
    _ = try bm.add_many(php.allocator, args.indices);
    return .{ .bitmap = bm };
}

pub fn deinit(self: *@This()) void {
    self.bitmap.deinit(php.allocator);
}

pub fn iterate(self: *@This()) Iterator {
    return .init(self.bitmap);
}

pub fn readDimension(self: *@This(), key: php.Value, _: php.Value.Access) !php.Value {
    const index = try getIndex(key);
    const found = self.bitmap.contains(index);
    return .fromBoolean(found);
}

pub fn hasDimension(_: *@This(), _: php.Value, _: bool) bool {
    return true;
}

pub fn writeDimension(self: *@This(), key: php.Value, value: php.Value) !void {
    const index = try getIndex(key);
    const state = try value.getBoolean();
    if (state) {
        try self.bitmap.add(php.allocator, index);
    } else {
        try self.bitmap.remove(php.allocator, index);
    }
}

pub fn countElements(self: *@This()) usize {
    const card = self.bitmap.get_cardinality();
    return @intCast(card);
}

pub fn getProperties(self: *@This(), _: Object.PropertiesPurpose) ?*php.Array {
    const arr: *php.Array = .create();
    var iter: zroaring.Iterator = .init(self.bitmap);
    while (iter.next()) |index| {
        arr.set(index, .fromBoolean(true));
    }
    return arr;
}

pub fn compareWith(self: *@This(), other_value: php.Value) !c_int {
    const other = try other_value.getCustom(@This());
    return if (self.bitmap.equals(other.bitmap))
        0
    else if (@intFromPtr(self) < @intFromPtr(other))
        -1
    else
        1;
}

pub fn doOperation(opcode: Object.Opcode, op1: php.Value, op2: php.Value) !php.Value {
    const self = try op1.getCustom(@This());
    const other = try op2.getCustom(@This());
    const output = switch (opcode) {
        .bitwise_and => try self.bitmap.@"and"(php.allocator, other.bitmap),
        .bitwise_or => try self.bitmap.@"or"(php.allocator, other.bitmap),
        .bitwise_xor => try self.bitmap.xor(php.allocator, other.bitmap),
        else => return error.IllegalOperation,
    };
    const result: @This() = .{ .bitmap = output };
    return .fromAny(result, .{});
}

const Iterator = struct {
    pub fn init(bitmap: zroaring.Bitmap) @This() {
        return .{ .bm_iter = .init(bitmap) };
    }

    pub fn next(self: *@This()) ?@Tuple(&.{ u32, bool }) {
        const index = self.bm_iter.next() orelse return null;
        return .{ index, true };
    }

    bm_iter: zroaring.Iterator,
};

fn getIndex(key: php.Value) !u32 {
    const index = try key.getUnsigned();
    if (index > std.math.maxInt(u32)) return error.Overflow;
    return @intCast(index);
}

bitmap: zroaring.Bitmap,
