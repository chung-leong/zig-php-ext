const std = @import("std");

const php = @import("../root.zig");
const c = php.c;
const php_al = php.allocator;
const String = php.String;

pub const vtable: std.mem.Allocator.VTable = .{
    .alloc = alloc,
    .resize = resize,
    .remap = remap,
    .free = free,
};

fn alloc(_: *anyopaque, len: usize, alignment: std.mem.Alignment, return_address: usize) ?[*]u8 {
    const mem_offset = @offsetOf(c.zend_string, "val");
    const total_len = std.mem.alignForward(usize, mem_offset + len + 1, c.ZEND_MM_ALIGNMENT);
    const byte_ptr = php_al.rawAlloc(total_len, alignment, return_address) orelse return null;
    @memset(byte_ptr[0..mem_offset], 0);
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
    const mem_offset = @offsetOf(c.zend_string, "val");
    const start_address = @intFromPtr(memory.ptr) - mem_offset;
    const total_len = std.mem.alignForward(usize, mem_offset + memory.len, c.ZEND_MM_ALIGNMENT);
    const byte_ptr: [*]u8 = @ptrFromInt(start_address);
    const str: *String = @ptrCast(@alignCast(byte_ptr));
    if (str.isUnitialized()) {
        // string was never created
        const actual_memory = byte_ptr[0..total_len];
        php_al.rawFree(actual_memory, alignment, return_address);
    } else {
        str.release();
    }
}
