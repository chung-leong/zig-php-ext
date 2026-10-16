const std = @import("std");

const php = @import("../../root.zig");
const c = php.c;
const pi = php.imports;
const Array = php.Array;
const Class = php.Class;
const failure = php.failure;
const Function = php.Function;
const Object = php.Object;
const Iterator = Object.Iterator;
const php_al = php.allocator;
const String = php.String;
const Value = php.Value;
const Access = Value.Access;
const Kind = Value.Kind;
const argCount = php.util.argCount;
const ArgType = php.util.ArgType;
const errable = php.util.errable;
const ReturnType = php.util.ReturnType;
const WithoutError = php.util.WithoutError;

pub fn @"fn"(comptime T: type) type {
    if (!@hasDecl(T, "next")) @compileError("No next method: " ++ @typeName(T));
    const Next = @TypeOf(T.next);
    const next_arg_count = comptime argCount(Next);
    const NextArg0 = ArgType(Next, 0);
    if (NextArg0 != *T) @compileError("Next method does not accept self pointer: " ++ @typeName(Next));
    if (next_arg_count == 2) {
        const NextArg1 = ArgType(Next, 1);
        if (NextArg1 != std.mem.Allocator) @compileError("Next method can only accept an allocator as its sole argument");
    }
    const NextRT = WithoutError(ReturnType(Next));
    if (@typeInfo(NextRT) != .optional) {
        @compileError("Next method does not return optional value : " ++ @typeName(Next));
    }
    const Entry = @typeInfo(NextRT).optional.child;
    const Payload = init: {
        switch (@typeInfo(Entry)) {
            .@"struct" => |st| switch (st.is_tuple) {
                true => switch (st.field_types.len) {
                    2 => {
                        const Key = st.field_types[0];
                        if (Key != *String and Key != c_long and Key != Value) {
                            @compileError("Key must be Value, *String, or c_long");
                        }
                        break :init st.field_types[1];
                    },
                    else => @compileError("Tuple with two items expected"),
                },
                else => break :init Entry,
            },
            else => break :init Entry,
        }
    };
    return struct {
        pub fn create(custom: T) !*@This() {
            const self = try php_al.create(@This());
            self.iter = .init(&methods);
            self.custom = custom;
            self.has_value = false;
            self.index = 0;
            return self;
        }

        pub fn iterator(self: *@This()) *Iterator {
            return @ptrCast(&self.iter);
        }

        fn fromIter(iter: *Iterator) *@This() {
            return @fieldParentPtr("iter", iter);
        }

        fn retrieve(self: *@This()) void {
            self.tryRetrieve() catch |err| {
                failure.throw(err);
            };
        }

        fn tryRetrieve(self: *@This()) !void {
            if (!self.has_value) {
                const result = switch (next_arg_count) {
                    1 => try errable(self.custom.next()),
                    2 => try errable(self.custom.next(php_al)),
                    else => unreachable,
                };
                if (result) |entry| {
                    const key = if (Entry == Payload) self.index else entry[0];
                    self.key = .fromAny(key);
                    const payload = if (Entry == Payload) entry else entry[1];
                    self.iter.data().* = .fromAny(payload);
                    self.has_value = true;
                }
            }
        }

        fn clear(self: *@This()) void {
            if (self.has_value) {
                self.key.release();
                self.iter.data().release();
                self.has_value = false;
            }
        }

        fn destroy(iter: *Iterator) callconv(.c) void {
            const self = fromIter(iter);
            if (@hasDecl(T, "deinit")) {
                self.custom.deinit();
            }
            self.clear();
        }

        fn isValid(iter: *Iterator) callconv(.c) c_int {
            const self = fromIter(iter);
            self.retrieve();
            return if (self.has_value) c.SUCCESS else c.FAILURE;
        }

        fn getCurrentData(iter: *Iterator) callconv(.c) *Value {
            const self = fromIter(iter);
            self.retrieve();
            return self.iter.data();
        }

        fn getCurrentKey(iter: *Iterator, key_ptr: *Value) callconv(.c) void {
            const self = fromIter(iter);
            self.retrieve();
            key_ptr.* = self.key;
        }

        fn moveForward(iter: *Iterator) callconv(.c) void {
            const self = fromIter(iter);
            if (!self.has_value) self.retrieve();
            self.clear();
            self.index += 1;
        }

        fn rewind(iter: *Iterator) callconv(.c) void {
            if (@hasDecl(T, "reset")) {
                const self = fromIter(iter);
                if (self.index > 0) {
                    self.clear();
                    self.index = 0;
                    self.custom.reset();
                }
            }
        }

        const methods: Iterator.Functions = .{
            .dtor = @ptrCast(&destroy),
            .valid = @ptrCast(&isValid),
            .get_current_data = @ptrCast(&getCurrentData),
            .get_current_key = @ptrCast(&getCurrentKey),
            .move_forward = @ptrCast(&moveForward),
            .rewind = @ptrCast(&rewind),
        };

        iter: Iterator align(@max(@alignOf(Iterator), @alignOf(T))),
        custom: T,
        key: Value,
        index: usize,
        has_value: bool,
    };
}
