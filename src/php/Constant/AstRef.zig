const std = @import("std");
const builtin = @import("builtin");

const php = @import("../root.zig");
const c = php.c;
const php_al = php.allocator;
const pi = php.imports;
const String = php.String;
const Value = php.Value;

pub fn createZval(value: Value, attr: Attribute) *@This() {
    const bytes = php_al.alloc(u8, @sizeOf(c.zend_ast_zval)) catch unreachable;
    const z_ast_val: *c.zend_ast_zval = @ptrCast(@alignCast(bytes));
    z_ast_val.kind = @backingInt(Kind.zval);
    z_ast_val.attr = @backingInt(attr);
    z_ast_val.val = value.toZval();
    z_ast_val.val.u2.lineno = 0;
    return @ptrCast(z_ast_val);
}

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
    writeZval(class_node, .fromString(class_name), .fq);
    writeZval(const_node, .fromString(const_name), .fq);
    writeNode(class_const_node, .class_const, .{ class_node, const_node });
    return @ptrCast(ref);
}

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
    method_reference = c.ZEND_AST_METHOD_REFERENCE,
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
pub const Attribute = enum(u16) {
    fq = c.ZEND_NAME_FQ,
    not_fq = c.ZEND_NAME_NOT_FQ,
    relative = c.ZEND_NAME_RELATIVE,

    pub const none: @This() = .fq;
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
                total_required += nodeSize(node_info);
            }
            break :init total_required;
        };

        pub fn init(omitting: anytype) @This() {
            var len = total_byte_count;
            for (omitting) |tag| {
                const node_info = @field(descriptor, @tagName(tag));
                len -= nodeSize(node_info);
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
            return switch (T) {
                c.zend_ast => @sizeOf(T) + @sizeOf(*T) * (node_info.child_count - 1),
                else => @sizeOf(T),
            };
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

fn writeNode(node: *c.zend_ast, kind: Kind, children: anytype) void {
    node.* = .{
        .kind = @backingInt(kind),
    };
    const child_ptr: [*]*c.zend_ast = @ptrCast(&node.child[0]);
    inline for (children, 0..) |child, i| child_ptr[i] = @ptrCast(child);
}

fn writeZval(node: *c.zend_ast_zval, value: Value, attr: Attribute) void {
    node.* = .{
        .kind = @backingInt(Kind.zval),
        .attr = @backingInt(attr),
        .val = value.toZval(),
    };
}

impl: c.zend_ast_ref,
