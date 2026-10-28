const php = @import("php/root.zig");
const Object = php.Object;
const String = php.String;
const Value = php.Value;

pub fn init(args: struct {
    length: usize,
    options: struct {
        max_byte_length: ?usize = null,
    } = .{},
}) @This() {
    const max_len = args.options.max_byte_length orelse args.length;
    const str: *String = .createUninitialized(max_len);
    @memset(@constCast(str.slice()), 0);
    return .{
        .string = str,
        .length = args.length,
        .max_length = args.options.max_byte_length,
    };
}

pub fn deinit(self: *@This()) void {
    if (self.string) |str| str.release();
}

pub fn getElements(self: *const @This(), comptime T: type, offset: usize, len: usize) ![]T {
    const str = self.string orelse return error.DetachedArrayBuffer;
    const slice = @constCast(str.slice());
    const ptr: [*]T = @ptrCast(@alignCast(&slice[offset]));
    return ptr[0..len];
}

pub fn castObject(self: *@This(), kind: Value.Kind) !Value {
    const str = self.string orelse return error.DetachedArrayBuffer;
    return switch (kind) {
        .boolean => .fromBoolean(true),
        .string => create: {
            const new_str: *String = switch (str.length() == self.length) {
                true => str.retain(),
                false => .create(str.slice()[0..self.length]),
            };
            break :create .fromString(new_str);
        },
        else => error.InvalidOperation,
    };
}

pub fn @"get byteLength"(self: *@This()) usize {
    return self.length;
}
pub fn @"get detached"(self: *@This()) bool {
    return self.string == null;
}
pub fn @"get maxByteLength"(self: *@This()) usize {
    return self.max_length orelse self.length;
}
pub fn @"get resizable"(self: *@This()) bool {
    return self.max_length != null;
}

pub fn @"call resize"(self: *@This(), args: struct {
    new_length: usize,
}) !void {
    if (self.string == null) return error.DetachedArrayBuffer;
    const max = self.max_length orelse return error.ArrayBufferNotResizable;
    if (args.new_length > max) return error.OutOfBound;
    self.length = args.new_length;
}

pub fn @"call slice"(self: *@This(), args: struct {
    start: ?isize,
    end: ?isize,
}) !*Object {
    const str = self.string orelse return error.DetachedArrayBuffer;
    const start = self.toAbsoluteIndex(args.start) orelse 0;
    const end = self.toAbsoluteIndex(args.end) orelse self.length;
    const new_slice: []const u8 = switch (start < end) {
        true => str.slice()[start..end],
        false => "",
    };
    const new_str: *String = .create(new_slice);
    return .createCustom(@This(), .{
        .string = new_str,
        .length = new_str.length(),
    });
}

pub fn @"call transfer"(self: *@This(), args: struct {
    new_length: ?usize,
}) !*Object {
    const new_len = args.new_length orelse self.length;
    if (self.max_length) |max| {
        if (new_len > max) return error.OutOfBound;
    }
    const new_str = try self.reallocate(new_len);
    return .createCustom(@This(), .{
        .string = new_str,
        .length = new_len,
        .max_length = self.max_length,
    });
}

pub fn @"call transferToFixedLength"(self: *@This(), args: struct {
    new_length: ?usize,
}) !*Object {
    const new_len = args.new_length orelse self.length;
    const new_str = try self.reallocate(new_len);
    return .createCustom(@This(), .{
        .string = new_str,
        .length = new_len,
    });
}

fn toAbsoluteIndex(self: *@This(), arg: ?isize) ?usize {
    const i = arg orelse return null;
    return switch (i >= 0) {
        true => @min(@as(usize, @intCast(i)), self.length),
        // negative indice count from the end
        false => switch (@as(usize, @intCast(-i)) < self.length) {
            true => self.length - @as(usize, @intCast(-i)),
            false => 0,
        },
    };
}

fn reallocate(self: *@This(), new_len: usize) !*String {
    const str = self.string orelse return error.DetachedArrayBuffer;
    const slice = str.slice();
    self.string = null;
    self.length = 0;
    if (new_len <= slice.len) return str;
    defer str.release();
    const new_str: *String = .createUninitialized(new_len);
    const new_slice = @constCast(new_str.slice());
    @memcpy(new_slice[0..slice.len], slice);
    @memset(new_slice[slice.len..], 0);
    return new_str;
}

string: ?*String,
length: usize,
max_length: ?usize = null,
