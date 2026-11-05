const std = @import("std");

const php = @import("../root.zig");
const c = php.c;
const Array = php.Array;
const Class = php.Class;
const Value = php.Value;

pub fn fixProblematicConstants() void {
    const cg = php.globals("compiler");
    const classes: *Array = @ptrCast(cg.class_table);
    var class_iter = classes.iterate(.{});
    while (class_iter.next()) |class_value| {
        const class: *Class = @ptrCast(@alignCast(class_value.pointer()));
        if (class.flags().has_ast_constants) {
            const constants = class.constants();
            var const_iter = constants.iterate(.{});
            while (const_iter.next()) |const_value| {
                const constant: *Class.Constant = @ptrCast(@alignCast(const_value.pointer()));
                const constant_value: *Value = @ptrCast(&constant.impl.value);
                if (constant_value.kind() == .constant_ast) {
                    // the first instruction is right after the zend_ast_ref struct
                    const ast_ptr: [*]u8 = @ptrCast(constant_value.impl.value.ast);
                    const ast: *c.zend_ast = @ptrCast(@alignCast(&ast_ptr[@sizeOf(c.zend_ast_ref)]));
                    const ast_kind: php.Constant.AstRef.Kind = @fromBackingInt(@intCast(ast.kind));
                    // PHP asserts on const_enum_init for some reason
                    if (ast_kind != .const_enum_init) {
                        // get around assertion at clean-up by forcing the correct value in there
                        // since the constants are being deleted, the mismatch doesn't matter
                        ast.kind = @backingInt(php.Constant.AstRef.Kind.const_enum_init);
                    }
                }
            }
        }
    }
}
