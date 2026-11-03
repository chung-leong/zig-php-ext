const std = @import("std");

const php = @import("php/root.zig");
const Object = php.Object;
const Value = php.Value;

const NumberIterator = struct {
    pub fn next(self: *@This()) ?i32 {
        if (self.current > self.last) return null;
        defer self.current += 1;
        return self.current;
    }

    current: i32 = 0,
    last: i32,
};

pub fn getIterator(_: *@This()) !?*Object.Iterator {
    php.print("getIterator\n", .{});
    const iter: NumberIterator = .{ .last = 4 };
    const custom_iter = try Object.Iterator.Custom(@TypeOf(iter)).create(iter);
    return custom_iter.iterator();
}
