//! Allocator that allocates memory from PHP's memory manager.
const std = @import("std");

const php = @import("root.zig");
const argCount = php.util.argCount;
const c = php.c;
const pi = php.imports;

/// The allocator's vtable. Used by `php.allocator`.
pub const vtable: std.mem.Allocator.VTable = .{
    .alloc = alloc,
    .resize = resize,
    .remap = remap,
    .free = free,
};
/// Different allocation modes.
pub const Mode = enum { persistent, per_request };
/// The current allocation mode. When set to `persistent`, allocated memory persists until it's
/// explicitly freed. Memory allocated under `per_request` mode on the other hand are
/// automatically reclaimed by the language engine at the end of a request.
pub threadlocal var mode: Mode = .persistent;

fn alloc(_: *anyopaque, len: usize, alignment: std.mem.Alignment, return_address: usize) ?[*]u8 {
    _ = return_address;
    _ = alignment;
    std.debug.assert(len > 0);
    const ptr = switch (mode) {
        .persistent => malloc(len),
        .per_request => emalloc(len, @src()),
    };
    return @ptrCast(ptr);
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
    _ = return_address;
    _ = alignment;
    switch (mode) {
        .persistent => c.free(memory.ptr),
        .per_request => efree(memory.ptr, @src()),
    }
}

fn emalloc(size: usize, comptime src: std.builtin.SourceLocation) [*]u8 {
    const ptr = switch (comptime argCount(@TypeOf(pi._emalloc))) {
        5 => pi._emalloc(size, src.file, src.line, null, 0),
        1 => pi._emalloc(size),
        else => @compileError("Unexpected _emalloc argument count"),
    };
    return @ptrCast(ptr);
}

fn efree(ptr: *anyopaque, comptime src: std.builtin.SourceLocation) void {
    switch (comptime argCount(@TypeOf(pi._efree))) {
        5 => pi._efree(ptr, src.file, src.line, null, 0),
        1 => pi._efree(ptr),
        else => @compileError("Unexpected _efree argument count"),
    }
}

fn malloc(size: usize) [*]u8 {
    const src = @src();
    const ptr = switch (comptime argCount(@TypeOf(pi.__zend_malloc))) {
        5 => pi.__zend_malloc(size, src.file, src.line + 1, null, 0),
        1 => pi.__zend_malloc(size),
        else => @compileError("Unexpected __zend_malloc argument count"),
    };
    return @ptrCast(ptr);
}
