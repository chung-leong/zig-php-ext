const std = @import("std");

pub const Custom = @import("Enumeration/Custom.zig").@"fn";
const php = @import("root.zig");
const c = php.c;
const Array = php.Array;
const Class = php.Class;
const Constant = php.Constant;
const Object = php.Object;
const pi = php.imports;
const String = php.String;
const Value = php.Value;

pub fn class(self: *const @This()) *Class {
    return @ptrCast(@constCast(self));
}

pub fn register(comptime full_name: []const u8, kind: Value.Kind) !*@This() {
    var fn_entries = std.mem.zeroes([1]c.zend_function_entry);
    const cg = php.globals("compiler");
    const classes: *Array = @ptrCast(cg.class_table);
    if (classes.has(full_name)) return error.NameConflict;
    const zce = pi.zend_register_internal_enum(full_name.ptr, @backingInt(kind), &fn_entries);
    return @ptrCast(zce);
}

pub fn addFields(self: *@This(), comptime T: type) !void {
    switch (@typeInfo(T)) {
        .@"enum" => try self.addEnumFields(T),
        .@"struct" => |st| switch (st.layout) {
            .@"packed" => try self.addPackedStructFields(T),
            else => @compileError("Packed struct expected, received: " ++ @typeName(T)),
        },
        else => @compileError("Enum or packed struct expected, received: " ++ @typeName(T)),
    }
}

pub fn getCase(self: *@This(), name: *String) *Object {
    const zobj = pi.zend_enum_get_case(@ptrCast(self.class()), @ptrCast(name));
    return @ptrCast(zobj);
}

pub fn findCaseByValue(self: *@This(), value: Value) ?*Object {
    const cls = self.class();
    const table: *Array = @ptrCast(cls.impl.backed_enum_table);
    const name_value = table.get(value) catch return null;
    return self.getCase(name_value.string());
}

pub fn addCase(self: *@This(), name: *String, value: Value) void {
    var zval = value.toZval();
    pi.zend_enum_add_case(@ptrCast(self.class()), @ptrCast(name), &zval);
}

fn addEnumFields(self: *@This(), comptime T: type) !void {
    const cases, const aliases = comptime init: {
        const en = @typeInfo(T).@"enum";
        const count = en.field_names.len;
        var cases: [count]CaseInfo = undefined;
        for (en.field_names, en.field_values, 0..) |field_name, field_value, i| {
            cases[i] = .{ .name = field_name, .value = field_value };
        }
        var alias_count: usize = 0;
        for (en.decl_names) |decl_name| {
            if (@TypeOf(@field(T, decl_name)) == T) alias_count += 1;
        }
        var aliases: [alias_count]AliasInfo = undefined;
        var index: usize = 0;
        for (en.decl_names) |decl_name| {
            if (@TypeOf(@field(T, decl_name)) == T) {
                const decl_value = @field(T, decl_name);
                const field_index = for (en.field_values, 0..) |field_value, i| {
                    if (@backingInt(decl_value) == field_value) break i;
                };
                const field_name = en.field_names[field_index];
                aliases[index] = .{ .name = decl_name, .case_name = field_name };
                index += 1;
            }
        }
        break :init .{ cases, aliases };
    };
    inline for (cases) |case| {
        self.addCase(.static(case.name), .fromInteger(case.value));
    }
    // add aliases as constants
    const cls = self.class();
    inline for (aliases) |alias| {
        const ast_ref: *Constant.AstRef = .createClassConstFetch(cls.name(), .static(alias.case_name));
        const ast_value: Value = .{
            .impl = .{
                .u1 = .{ .type_info = c.IS_CONSTANT_AST },
                .value = .{ .ast = @ptrCast(ast_ref) },
            },
        };
        // class constant registration never fails actually--returning error union only for consistency
        const constant: *Class.Constant = try .register(alias.name, ast_value, cls);
        _ = constant;
    }
}

fn addPackedStructFields(self: *@This(), comptime T: type) !void {
    const cases = comptime init: {
        const st = @typeInfo(T).@"struct";
        var count: usize = 0;
        for (st.field_types) |FT| {
            if (FT == bool) count += 1;
        }
        var cases: [count]CaseInfo = undefined;
        var index: usize = 0;
        for (st.field_names, st.field_types) |field_name, FT| {
            if (FT == bool) {
                cases[index] = .{ .name = field_name, .value = 1 << @bitOffsetOf(T, field_name) };
                index += 1;
            }
        }
        break :init cases;
    };
    const cls = self.class();
    inline for (cases) |case| {
        // packed struct fields get added as constants
        const constant: *Class.Constant = try .register(case.name, .fromInteger(case.value), cls);
        _ = constant;
    }
}

const CaseInfo = struct {
    name: []const u8,
    value: comptime_int,
};
const AliasInfo = struct {
    name: []const u8,
    case_name: []const u8,
};

class_entry: Class,
