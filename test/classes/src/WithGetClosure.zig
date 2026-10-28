const std = @import("std");

const php = @import("php/root.zig");
const Object = php.Object;
const getter = Object.getter;
const setter = Object.setter;
const Function = php.Function;
const Arguments = Function.Arguments;
const Value = php.Value;

pub fn call(args: *Arguments, retval: *Value) !void {
    var arg_iter = args.iterate();
    const arg_struct = try arg_iter.extract(php.allocator, struct {
        number1: f64,
        number2: f64,
    });
    php.print("{}\n", .{arg_struct});
    retval.* = .fromFloat(arg_struct.number1 + arg_struct.number2);
}

pub fn getClosure(_: *@This(), check_only: bool) !Object.ClosureResult {
    php.print("getClosure: {}\n", .{check_only});
    return .{ .function = &closure };
}

const closure: Function = .init(call, .{ .self_source = .{ .none = {} } });
