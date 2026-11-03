const std = @import("std");

const php = @import("php/root.zig");
const Object = php.Object;
const getter = Object.getter;
const setter = Object.setter;
const Value = php.Value;

pub const @"get value" = getter(@This(), .float);
pub const @"set value" = setter(@This(), .float);

pub fn doOperation(opcode: Object.Opcode, op1: Value, op2: Value) !Value {
    const value1 = try getValue(op1);
    const value2 = try getValue(op2);
    php.print("doOperation: {} {d} {d}\n", .{
        opcode,
        try value1.getFloat(),
        try value2.getFloat(),
    });
    return try opcode.perform(value1, value2);
}

fn getValue(operand: Value) !Value {
    return switch (operand.kind()) {
        .object => get: {
            const obj = operand.object();
            if (!obj.isCustom(@This())) return error.NotThisType;
            const self = obj.custom(@This());
            break :get .fromFloat(self.float);
        },
        else => operand,
    };
}

float: f64 = 0,
