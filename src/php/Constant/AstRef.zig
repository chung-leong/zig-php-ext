//! Data structure for referencing an Abstract Syntax Tree, used to constant expression.
const std = @import("std");
const builtin = @import("builtin");

const php = @import("../root.zig");
const c = php.c;
const php_al = php.allocator;
const pi = php.imports;
const String = php.String;
const Value = php.Value;
const isScalarType = php.util.isScalarType;

/// Create an AST for fetching a class constant.
pub fn createClassConstFetch(class_name: *String, const_name: *String) *@This() {
    var na: NodeAllocator(.{
        .ref = .{ .type = c.zend_ast_ref },
        .enum_init = .{ .type = c.zend_ast, .child_count = 2 },
        .class_name = .{ .type = c.zend_ast_zval },
        .const_name = .{ .type = c.zend_ast_zval },
        .class_const = .{ .type = c.zend_ast, .child_count = 2 },
    }) = .init(.{});
    const ref = na.alloc(.ref);
    const class_const_node = na.alloc(.class_const);
    const class_node = na.alloc(.class_name);
    const const_node = na.alloc(.const_name);
    writeRef(ref);
    writeZval(class_node, .fromString(class_name), 0);
    writeZval(const_node, .fromString(const_name), 0);
    writeNode(class_const_node, .class_const, .{ class_node, const_node });
    return @ptrCast(ref);
}
/// Create an AST for declaring an array or object literal based on the given argument. 
/// 
/// The function currently can only handler containers holding scalar elements.
pub fn createLiteral(comptime T: type, arg: T) *@This() {
    if (comptime !php.util.canBeConstant(T)) {
        @compileError("Unsupported type for constants: " ++ @typeName(T));
    }
    const constant_type: enum { array, tuple, object } = switch (@typeInfo(T)) {
        .array => .array,
        .@"struct" => |st| if (st.is_tuple) .tuple else .object,
        .pointer => .array,
        else => unreachable,
    };
    const child_count = switch (constant_type) {
        .array => arg.len,
        .tuple, .object => @typeInfo(T).@"struct".field_names.len,
    };
    const cast_to_obj = switch (constant_type) {
        .array, .tuple => false,
        // cast-to-object is only supported in 8.5 and up
        .object => php.minor_version >= 5 or php.major_version > 8,
    };
    var na: NodeAllocator(.{
        .ref = .{ .type = c.zend_ast_ref },
        .cast = .{ .type = c.zend_ast },
        .array = .{ .type = c.zend_ast_list, .child_count = child_count },
        .array_elem = .{ .type = c.zend_ast, .child_count = 2, .count = child_count },
        .value = .{ .type = c.zend_ast_zval, .count = child_count },
        .key = .{ .type = c.zend_ast_zval, .count = child_count },
    }) = .init(switch (constant_type) {
        .array, .tuple => .{ .omitting = &.{ .cast, .key } },
        .object => if (cast_to_obj) .{} else .{ .omitting = &.{.cast} },
    });
    const ref = na.alloc(.ref);
    // the element that immediately follows the ref is the root expression
    const cast_node = if (cast_to_obj) na.alloc(.cast) else null;
    const array_node = na.alloc(.array);
    var array_elems: [child_count]*c.zend_ast = undefined;
    var values: [child_count]*c.zend_ast_zval = undefined;
    var keys: [child_count]?*c.zend_ast_zval = undefined;
    for (&array_elems, &values, &keys) |*array_elem_ptr, *value_ptr, *key_ptr| {
        array_elem_ptr.* = na.alloc(.array_elem);
        value_ptr.* = na.alloc(.value);
        key_ptr.* = if (constant_type == .object) na.alloc(.value) else null;
    }
    writeRef(ref);
    // write the elements
    switch (constant_type) {
        .array => {
            for (array_elems, values, keys, 0..) |array_elem, value, key, i| {
                const arg_elem = arg[i];
                writeZval(value, .fromAny(arg_elem, .{}), 0);
                writeNode(array_elem, .array_elem, .{ value, key });
            }
        },
        inline .tuple, .object => {
            const field_names = @typeInfo(T).@"struct".field_names;
            inline for (array_elems, values, keys, field_names) |array_elem, value, key, field_name| {
                const arg_elem = @field(arg, field_name);
                writeZval(value, .fromAny(arg_elem, .{}), 0);
                if (key) |k| writeZval(k, .fromString(.static(field_name)), 0);
                writeNode(array_elem, .array_elem, .{ value, key });
            }
        },
    }
    writeNode(array_node, .array, array_elems);
    if (cast_to_obj) {
        writeNode(cast_node, .cast, .{array_node});
        cast_node.attr = c.IS_OBJECT;
    }
    return @ptrCast(ref);
}
/// Place the AST reference in a `Value`.
pub fn toValue(self: *@This()) Value {
    return .{
        .impl = .{
            .u1 = .{ .type_info = c.IS_CONSTANT_AST },
            .value = .{ .ast = @ptrCast(self) },
        },
    };
}
/// Different kinds of AST nodes.
pub const Kind = enum(u16) {
    // special nodes
    zval = c.ZEND_AST_ZVAL,
    constant = c.ZEND_AST_CONSTANT,
    znode = c.ZEND_AST_ZNODE,

    // declaration nodes
    func_decl = c.ZEND_AST_FUNC_DECL,
    closure = c.ZEND_AST_CLOSURE,
    method = c.ZEND_AST_METHOD,
    class = c.ZEND_AST_CLASS,
    arrow_func = c.ZEND_AST_ARROW_FUNC,

    // list nodes
    arg_list = c.ZEND_AST_ARG_LIST,
    array = c.ZEND_AST_ARRAY,
    encaps_list = c.ZEND_AST_ENCAPS_LIST,
    expr_list = c.ZEND_AST_EXPR_LIST,
    stmt_list = c.ZEND_AST_STMT_LIST,
    @"if" = c.ZEND_AST_IF,
    switch_list = c.ZEND_AST_SWITCH_LIST,
    catch_list = c.ZEND_AST_CATCH_LIST,
    param_list = c.ZEND_AST_PARAM_LIST,
    closure_uses = c.ZEND_AST_CLOSURE_USES,
    prop_decl = c.ZEND_AST_PROP_DECL,
    const_decl = c.ZEND_AST_CONST_DECL,
    class_const_decl = c.ZEND_AST_CLASS_CONST_DECL,
    name_list = c.ZEND_AST_NAME_LIST,
    trait_adaptations = c.ZEND_AST_TRAIT_ADAPTATIONS,
    use = c.ZEND_AST_USE,
    type_union = c.ZEND_AST_TYPE_UNION,
    type_intersection = c.ZEND_AST_TYPE_INTERSECTION,
    attribute_list = c.ZEND_AST_ATTRIBUTE_LIST,
    attribute_group = c.ZEND_AST_ATTRIBUTE_GROUP,
    match_arm_list = c.ZEND_AST_MATCH_ARM_LIST,

    // 0 child nodes
    magic_const = c.ZEND_AST_MAGIC_CONST,
    type = c.ZEND_AST_TYPE,
    constant_class = c.ZEND_AST_CONSTANT_CLASS,
    callable_convert = c.ZEND_AST_CALLABLE_CONVERT,

    // 1 child node
    @"var" = c.ZEND_AST_VAR,
    @"const" = c.ZEND_AST_CONST,
    unpack = c.ZEND_AST_UNPACK,
    unary_plus = c.ZEND_AST_UNARY_PLUS,
    unary_minus = c.ZEND_AST_UNARY_MINUS,
    cast = c.ZEND_AST_CAST,
    empty = c.ZEND_AST_EMPTY,
    isset = c.ZEND_AST_ISSET,
    silence = c.ZEND_AST_SILENCE,
    shell_exec = c.ZEND_AST_SHELL_EXEC,
    print = c.ZEND_AST_PRINT,
    include_or_eval = c.ZEND_AST_INCLUDE_OR_EVAL,
    unary_op = c.ZEND_AST_UNARY_OP,
    pre_inc = c.ZEND_AST_PRE_INC,
    pre_dec = c.ZEND_AST_PRE_DEC,
    post_inc = c.ZEND_AST_POST_INC,
    post_dec = c.ZEND_AST_POST_DEC,
    yield_from = c.ZEND_AST_YIELD_FROM,
    class_name = c.ZEND_AST_CLASS_NAME,

    global = c.ZEND_AST_GLOBAL,
    unset = c.ZEND_AST_UNSET,
    @"return" = c.ZEND_AST_RETURN,
    label = c.ZEND_AST_LABEL,
    ref = c.ZEND_AST_REF,
    halt_compiler = c.ZEND_AST_HALT_COMPILER,
    echo = c.ZEND_AST_ECHO,
    throw = c.ZEND_AST_THROW,
    goto = c.ZEND_AST_GOTO,
    @"break" = c.ZEND_AST_BREAK,
    @"continue" = c.ZEND_AST_CONTINUE,

    // 2 child nodes
    dim = c.ZEND_AST_DIM,
    prop = c.ZEND_AST_PROP,
    nullsafe_prop = c.ZEND_AST_NULLSAFE_PROP,
    static_prop = c.ZEND_AST_STATIC_PROP,
    call = c.ZEND_AST_CALL,
    class_const = c.ZEND_AST_CLASS_CONST,
    assign = c.ZEND_AST_ASSIGN,
    assign_ref = c.ZEND_AST_ASSIGN_REF,
    assign_op = c.ZEND_AST_ASSIGN_OP,
    binary_op = c.ZEND_AST_BINARY_OP,
    greater = c.ZEND_AST_GREATER,
    equal = c.ZEND_AST_GREATER_EQUAL,
    @"and" = c.ZEND_AST_AND,
    @"or" = c.ZEND_AST_OR,
    array_elem = c.ZEND_AST_ARRAY_ELEM,
    new = c.ZEND_AST_NEW,
    instanceof = c.ZEND_AST_INSTANCEOF,
    yield = c.ZEND_AST_YIELD,
    coalesce = c.ZEND_AST_COALESCE,
    assign_coalesce = c.ZEND_AST_ASSIGN_COALESCE,

    static = c.ZEND_AST_STATIC,
    @"while" = c.ZEND_AST_WHILE,
    do_while = c.ZEND_AST_DO_WHILE,
    if_elem = c.ZEND_AST_IF_ELEM,
    @"switch" = c.ZEND_AST_SWITCH,
    switch_case = c.ZEND_AST_SWITCH_CASE,
    declare = c.ZEND_AST_DECLARE,
    use_trait = c.ZEND_AST_USE_TRAIT,
    trait_precedence = c.ZEND_AST_TRAIT_PRECEDENCE,
    namespace = c.ZEND_AST_NAMESPACE,
    use_elem = c.ZEND_AST_USE_ELEM,
    trait_alias = c.ZEND_AST_TRAIT_ALIAS,
    group_use = c.ZEND_AST_GROUP_USE,
    class_const_group = c.ZEND_AST_CLASS_CONST_GROUP,
    attribute = c.ZEND_AST_ATTRIBUTE,
    match = c.ZEND_AST_MATCH,
    match_arm = c.ZEND_AST_MATCH_ARM,
    named_arg = c.ZEND_AST_NAMED_ARG,

    // child nodes
    method_call = c.ZEND_AST_METHOD_CALL,
    nullsafe_method_call = c.ZEND_AST_NULLSAFE_METHOD_CALL,
    static_call = c.ZEND_AST_STATIC_CALL,
    conditional = c.ZEND_AST_CONDITIONAL,

    @"try" = c.ZEND_AST_TRY,
    @"catch" = c.ZEND_AST_CATCH,
    prop_group = c.ZEND_AST_PROP_GROUP,
    prop_elem = c.ZEND_AST_PROP_ELEM,
    const_elem = c.ZEND_AST_CONST_ELEM,

    // Pseudo node for initializing enums
    const_enum_init = c.ZEND_AST_CONST_ENUM_INIT,

    // 4 child nodes
    @"for" = c.ZEND_AST_FOR,
    foreach = c.ZEND_AST_FOREACH,
    enum_case = c.ZEND_AST_ENUM_CASE,

    // 5 child nodes
    param = c.ZEND_AST_PARAM,
};

fn NodeAllocator(descriptor: anytype) type {
    const Descriptor = @TypeOf(descriptor);
    const Tag = std.meta.FieldEnum(Descriptor);
    return struct {
        const total_byte_count = init: {
            var total_required: usize = 0;
            const field_names = @typeInfo(Descriptor).@"struct".field_names;
            for (field_names) |field_name| {
                const node_info = @field(descriptor, field_name);
                const count = if (@hasField(@TypeOf(node_info), "count")) node_info.count else 1;
                total_required += nodeSize(node_info) * count;
            }
            break :init total_required;
        };

        pub fn init(comptime options: struct { omitting: []const Tag = &.{} }) @This() {
            var len = total_byte_count;
            inline for (options.omitting) |tag| {
                const node_info = @field(descriptor, @tagName(tag));
                const count = if (@hasField(@TypeOf(node_info), "count")) node_info.count else 1;
                len -= nodeSize(node_info) * count;
            }
            return .{ .bytes = php_al.alloc(u8, len) catch unreachable };
        }

        pub fn alloc(self: *@This(), comptime tag: Tag) RT: {
            const node_info = @field(descriptor, @tagName(tag));
            break :RT *node_info.type;
        } {
            const node_info = @field(descriptor, @tagName(tag));
            const required = nodeSize(node_info);
            const remaining = self.bytes.len - self.offset;
            if (builtin.mode == .debug) {
                if (remaining < required) @panic("NodeAllocator did not allocate enough memory");
            }
            const slice = self.bytes[self.offset .. self.offset + required];
            self.offset += required;
            return @ptrCast(@alignCast(slice.ptr));
        }

        fn nodeSize(node_info: anytype) usize {
            const T = node_info.type;
            const size = switch (@hasField(@TypeOf(node_info), "child_count")) {
                true => @sizeOf(T) + @sizeOf(*T) * (node_info.child_count - 1),
                false => @sizeOf(T),
            };
            return size;
        }

        bytes: []u8,
        offset: usize = 0,
    };
}

fn setKind(anynode: anytype, kind: Kind) void {
    const node: *c.zend_ast = @ptrCast(anynode);
    node.kind = @fromBackingInt(kind);
}

fn writeRef(ref: *c.zend_ast_ref) void {
    ref.* = .{
        .gc = .{
            .refcount = 1,
            .u = .{ .type_info = c.GC_CONSTANT_AST | c.GC_PERSISTENT | c.GC_IMMUTABLE },
        },
    };
}

fn writeNode(node: anytype, kind: Kind, children: anytype) void {
    node.* = .{
        .kind = @backingInt(kind),
    };
    const child_ptr: [*]?*c.zend_ast = @ptrCast(&node.child[0]);
    inline for (children, 0..) |child, i| child_ptr[i] = @ptrCast(child);
    if (@hasField(@TypeOf(node.*), "children")) node.children = children.len;
}

fn writeZval(node: *c.zend_ast_zval, value: Value, attr: u16) void {
    node.* = .{
        .kind = @backingInt(Kind.zval),
        .attr = attr,
        .val = value.toZval(),
    };
}

impl: c.zend_ast_ref,
