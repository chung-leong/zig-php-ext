const php = @import("php/root.zig");
const Array = php.Array;
const Object = php.Object;
const Value = php.Value;

pub fn initSelf(self: *@This()) !void {
    const obj: *Object = .fromCustom(self);
    self.array = .create();
    self.array.append(.fromObject(obj));
}

pub fn deinit(self: *@This()) void {
    self.array.release();
}

pub fn getGarbageCollection(self: *@This()) !Object.GarbageCollectionResult {
    php.print("getGarbageCollection\n", .{});
    return .{ .array = self.array };
}

array: *Array,
