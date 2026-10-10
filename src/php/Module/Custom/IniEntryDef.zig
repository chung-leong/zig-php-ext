const std = @import("std");

const php = @import("../../root.zig");
const c = php.c;
const Singleton = php.Singleton;
const String = php.String;
const Value = php.Value;
const failure = php.failure;
const pi = php.imports;
const unsupported = failure.unsupported;
const errable = php.util.errable;

pub const Kind = enum(u8) {
    user = c.ZEND_INI_USER,
    per_dir = c.ZEND_INI_PERDIR,
    system = c.ZEND_INI_SYSTEM,
    all = c.ZEND_INI_ALL,
};

pub fn init(allocator: std.mem.Allocator, container: anytype, comptime mod_name: [:0]const u8, comptime getter_name: [:0]const u8, comptime setter_name: [:0]const u8) @This() {
    const T = @TypeOf(container.*);
    const ini_name = mod_name ++ "." ++ getter_name;
    const kind: Kind = switch (getter_name.len == setter_name.len) {
        true => .all,
        false => init: {
            const suffix = setter_name[getter_name.len + 1 ..];
            for (std.meta.fieldNames(Kind)) |type_name| {
                if (std.mem.eql(u8, suffix, "(" ++ type_name ++ ")")) {
                    break :init @field(Kind, type_name);
                }
            } else @compileError("Not a valid ini field suffix: " ++ suffix);
        },
    };
    const getter = @field(T, php.util.getterPrefix(.instance) ++ getter_name);
    const payload = try errable(getter(container));
    const value = try fromPayload(allocator, payload);
    const setter = @field(T, php.util.setterPrefix(.instance) ++ setter_name);
    const updater = struct {
        pub fn onModify(_: *c.zend_ini_entry, text: *String, mh_arg1: *anyopaque, _: *anyopaque, _: *anyopaque, _: c_int) callconv(.c) c_int {
            tryModify(text, mh_arg1) catch |err| {
                failure.warn(err);
                return c.FAILURE;
            };
            return c.SUCCESS;
        }

        fn tryModify(text: *String, mh_arg1: *anyopaque) !void {
            const setter_ptr: *const @TypeOf(setter) = @ptrCast(mh_arg1);
            const target_container = Singleton(T).get();
            const Payload = php.util.ArgType(@TypeOf(setter), 1);
            const new_payload = try toPayload(Payload, text);
            return setter_ptr(target_container, new_payload);
        }
    };
    return .{
        .impl = .{
            .name = ini_name.ptr,
            .name_length = @intCast(ini_name.len),
            .value = value.ptr,
            .value_length = @intCast(value.len),
            .modifiable = @intFromEnum(kind),
            .on_modify = @ptrCast(&updater.onModify),
            .displayer = null,
            .mh_arg1 = @constCast(&setter),
            .mh_arg2 = null,
            .mh_arg3 = null,
        },
    };
}

fn fromPayload(allocator: std.mem.Allocator, arg: anytype) ![]const u8 {
    const T = @TypeOf(arg);
    return switch (@typeInfo(T)) {
        .bool => if (arg) "On" else "Off",
        .int, .float => try std.fmt.allocPrint(allocator, "{d}", .{arg}),
        .pointer => |pt| switch (pt.child) {
            u8 => arg,
            String => arg.slice(),
            else => unsupported(T),
        },
        .@"enum" => @tagName(arg),
        .@"struct" => |st| if (st.backing_integer) |Int|
            try std.fmt.allocPrint(allocator, "{d}", .{@as(Int, @bitCast(arg))})
        else
            unsupported(T),
        else => unsupported(T),
    };
}

fn toPayload(comptime T: type, str: *String) !T {
    return switch (@typeInfo(T)) {
        .bool => pi.zend_ini_parse_bool(@ptrCast(str)),
        .int => pi.zend_atol(@ptrCast(str)),
        .float => pi.zend_strtod(@ptrCast(str)),
        .pointer => |pt| switch (pt.child) {
            u8 => str.slice(),
            String => str.retain(),
            else => unsupported(T),
        },
        else => get: {
            const value: Value = .fromString(str);
            break :get value.convertTo(T);
        },
    };
}

impl: c.zend_ini_entry_def,
