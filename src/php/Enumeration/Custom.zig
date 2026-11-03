const php = @import("../root.zig");
const Array = php.Array;
const Class = php.Class;
const Enumeration = php.Enumeration;
const String = php.String;

pub fn @"fn"(comptime T: type) type {
    return struct {
        pub fn enumeration(self: *const @This()) *Enumeration {
            return @constCast(self.enum_entry);
        }

        pub fn name(_: *const @This()) *String {
            return canonical_name.?;
        }

        pub fn get() *@This() {
            return registered.?;
        }

        pub fn register(comptime full_name: []const u8) !*@This() {
            return registered orelse create: {
                const en: *Enumeration = try .register(full_name, .integer);
                try en.addFields(T);
                const self: *@This() = @ptrCast(en);
                registered = self;
                // when an enum is registered in multiple places, the first name encountered is
                // considered its canonical name
                canonical_name = String.static(full_name);
                break :create self;
            };
        }

        var registered: ?*@This() = null;
        var canonical_name: ?*String = null;

        enum_entry: Enumeration,
    };
}
