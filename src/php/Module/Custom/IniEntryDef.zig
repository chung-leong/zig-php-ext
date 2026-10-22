const php = @import("../../root.zig");
const c = php.c;
const failure = php.failure;
const IniEntry = php.IniEntry;
const pi = php.imports;
const Singleton = php.Singleton;
const String = php.String;
const Value = php.Value;
const unsupported = failure.unsupported;
const errable = php.util.errable;

pub fn init(
    ini_name: [:0]const u8,
    kind: IniEntry.Kind,
    def_value: [:0]const u8,
    on_modify: anytype,
) @This() {
    const ns = struct {
        pub fn handler(entry: *IniEntry, new_value: *String, _: *anyopaque, _: *anyopaque, _: *anyopaque, _: c_int) callconv(.c) c_int {
            if (on_modify(entry, new_value)) {
                return c.SUCCESS;
            } else |err| {
                failure.warn(err);
                return c.FAILURE;
            }
        }
    };
    return .{
        .impl = .{
            .name = ini_name.ptr,
            .name_length = @intCast(ini_name.len),
            .value = def_value.ptr,
            .value_length = @intCast(def_value.len),
            .modifiable = @backingInt(kind),
            .on_modify = @ptrCast(&ns.handler),
            .displayer = null,
            .mh_arg1 = null,
            .mh_arg2 = null,
            .mh_arg3 = null,
        },
    };
}

impl: c.zend_ini_entry_def,
