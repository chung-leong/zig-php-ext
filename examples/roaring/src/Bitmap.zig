const std = @import("std");

const zroaring = @import("zroaring");

const php = @import("php/root.zig");

pub fn init(args: struct { init: union(enum) {
    indices: []const u32,
    frozen: []const u8,
} = .{ .indices = &.{} } }) !@This() {
    switch (args.init) {
        .indices => |indices| {
            var bm: zroaring.Bitmap = .empty;
            _ = try bm.add_many(php.allocator, indices);
            return .{ .bitmap = bm };
        },
        .frozen => |frozen| {
            const bytes = try php.allocator.alignedAlloc(u8, .fromByteUnits(zroaring.constants.BLOCK_ALIGN), frozen.len);
            errdefer php.allocator.free(bytes);
            @memcpy(bytes, frozen);
            const bm: zroaring.Bitmap = try .frozen_view(php.allocator, bytes);
            return .{ .bitmap = bm, .frozen = bytes };
        },
    }
}

pub fn deinit(self: *@This()) void {
    self.bitmap.deinit(php.allocator);
    if (self.frozen) |bytes| php.allocator.free(bytes);
}

pub fn freeze(self: *@This()) !void {
    if (self.frozen != null) return;
    if (try self.bitmap.run_optimize(php.allocator)) {
        _ = try self.bitmap.shrink_to_fit(php.allocator);
    }
    const size = self.bitmap.frozen_size_in_bytes();
    const bytes = try php.allocator.alignedAlloc(u8, .fromByteUnits(zroaring.constants.BLOCK_ALIGN), size);
    errdefer php.allocator.free(bytes);
    try self.bitmap.frozen_serialize(bytes);
    const new_bm: zroaring.Bitmap = try .frozen_view(php.allocator, bytes);
    // free the existing one
    self.bitmap.deinit(php.allocator);
    self.bitmap = new_bm;
    self.frozen = bytes;
}

pub fn thaw(self: *@This()) !void {
    if (self.frozen == null) return;
    const new_bm = try self.bitmap.@"or"(php.allocator, self.bitmap);
    self.bitmap.deinit(php.allocator);
    php.allocator.free(self.frozen.?);
    self.bitmap = new_bm;
    self.frozen = null;
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
    if (self.frozen != null) return error.Frozen;
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

pub fn getProperties(self: *@This(), _: php.Object.PropertiesPurpose) ?*php.Array {
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

pub fn doOperation(opcode: php.Object.Opcode, op1: php.Value, op2: php.Value) !php.Value {
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

pub fn castObject(self: *@This(), kind: php.Value.Kind) !php.Value {
    return switch (kind) {
        .string => if (self.frozen) |bytes| .fromString(.create(bytes)) else error.NotFrozen,
        else => error.IllegalOperation,
    };
}

pub const @"call freeze" = freeze;
pub const @"call thaw" = thaw;

pub fn @"get frozen"(self: *@This()) bool {
    return self.frozen != null;
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
frozen: ?[]align(zroaring.constants.BLOCK_ALIGN) u8 = null,
