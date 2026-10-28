const std = @import("std");

const php = @import("../root.zig");
const Array = php.Array;
const List = php.List;
const Object = php.Object;
const String = php.String;
const Value = php.Value;

pub fn init(list: List) @This() {
    return .{ .list = list.retain() };
}

pub fn deinit(self: *@This()) void {
    self.list.release();
    self.current_value.release();
}

pub fn next(self: *@This()) ?Value {
    self.current_index +%= 1;
    self.current_value.release();
    self.current_value = self.list.read(self.current_index) catch {
        self.current_value = .fromNull();
        return null;
    };
    return self.current_value;
}

pub fn reset(self: *@This()) void {
    self.current_index = std.math.maxInt();
}

pub fn index(self: *@This()) usize {
    return self.current_index;
}

current_index: usize = std.math.maxInt(usize),
current_value: Value = .fromNull(),
list: List,
