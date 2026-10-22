const std = @import("std");

const php = @import("../../root.zig");
const c = php.c;
const Function = php.Function;

pub fn init(comptime T: type, comptime name: [:0]const u8, comptime func: anytype) @This() {
    const self_src: Function.SelfSource = .{ .singleton = T };
    const handler = Function.internalFunction(func, self_src);
    const handler_info = Function.handlerInfo(func, self_src);
    const zarg_info = arg_info_init: {
        const arg_count = 1 + handler_info.arguments.len + if (handler_info.is_variadic) 1 else 0;
        var arg_entries: [arg_count]c.zend_internal_arg_info = undefined;
        // the first array entry is used to store a zend_internal_function_info
        const fn_info_ptr: *c.zend_internal_function_info = @ptrCast(&arg_entries[0]);
        fn_info_ptr.* = .{ .required_num_args = handler_info.required_count };
        var j: usize = 1;
        for (handler_info.arguments) |a| {
            arg_entries[j] = .{
                .name = a.name,
                .type = .{
                    .type_mask = if (a.by_ref) 1 << c._ZEND_SEND_MODE_SHIFT else 0,
                },
            };
            j += 1;
        }
        if (handler_info.is_variadic) {
            arg_entries[j] = .{ .name = "" };
        }
        break :arg_info_init arg_entries;
    };
    const flags = c.ZEND_ACC_PUBLIC | switch (handler_info.is_variadic) {
        true => c.ZEND_ACC_VARIADIC,
        false => 0,
    };
    return .{
        .impl = .{
            .fname = name,
            .handler = @ptrCast(&handler),
            .arg_info = &zarg_info,
            .num_args = handler_info.arguments.len,
            .flags = flags,
        },
    };
}

impl: c.zend_function_entry,
