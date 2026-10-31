const std = @import("std");

const php = @import("../root.zig");
const c = php.c;
const php_al = php.allocator;
const Object = php.Object;
const ObjectLite = @import("Custom.zig").ObjectLite;

pub const vtable: std.mem.Allocator.VTable = .{
    .alloc = alloc,
    .resize = resize,
    .remap = remap,
    .free = free,
};

fn alloc(_: *anyopaque, len: usize, alignment: std.mem.Alignment, return_address: usize) ?[*]u8 {
    const obj_len = @sizeOf(ObjectLite);
    const mem_offset = std.mem.alignForward(usize, obj_len, alignment.toByteUnits());
    const total_len = mem_offset + len;
    const byte_ptr = php_al.rawAlloc(total_len, alignment, return_address) orelse return null;
    @memset(byte_ptr[0..obj_len], 0);
    return byte_ptr + mem_offset;
}

fn resize(_: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, return_address: usize) bool {
    _ = alignment;
    _ = return_address;
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
    const obj_len = @sizeOf(ObjectLite);
    const mem_offset = std.mem.alignForward(usize, obj_len, alignment.toByteUnits());
    const start_address = @intFromPtr(memory.ptr) - mem_offset;
    const total_len = mem_offset + memory.len;
    const byte_ptr: [*]u8 = @ptrFromInt(start_address);
    const obj: *Object = @ptrCast(@alignCast(byte_ptr));
    if (obj.isUninitialized()) {
        // object was never created
        const actual_memory = byte_ptr[0..total_len];
        php_al.rawFree(actual_memory, alignment, return_address);
    } else {
        obj.release();
    }
}
