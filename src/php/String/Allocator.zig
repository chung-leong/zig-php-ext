const std = @import("std");

const php = @import("../root.zig");
const String = php.String;

pub const vtable: std.mem.Allocator.VTable = .{
    .alloc = alloc,
    .resize = resize,
    .remap = remap,
    .free = free,
};

fn alloc(_: *anyopaque, len: usize, alignment: std.mem.Alignment, return_address: usize) ?[*]u8 {
    _ = return_address;
    _ = alignment;
    const str: *String = .createUninitialized(len);
    const s = str.slice();
    return @ptrCast(@constCast(s.ptr));
}

fn resize(_: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, return_address: usize) bool {
    _ = alignment;
    _ = return_address;
    std.debug.print("(String) resize: {d}\n", .{memory.len});
    std.debug.assert(new_len > 0);
    if (new_len <= memory.len) {
        return true; // in-place shrink always works
    }
    return false;
}

fn remap(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, return_address: usize) ?[*]u8 {
    std.debug.assert(new_len > 0);
    if (resize(ctx, memory, alignment, new_len, return_address)) {
        return memory.ptr;
    }
    return null;
}

fn free(_: *anyopaque, memory: []u8, alignment: std.mem.Alignment, return_address: usize) void {
    _ = return_address;
    _ = alignment;
    const str: *String = .fromOwnSlice(memory);
    str.release();
}
