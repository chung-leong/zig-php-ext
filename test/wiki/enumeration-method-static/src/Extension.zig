const php = @import("php/root.zig");

const Fruit = enum {
    apple,
    banana,
    cherry,
    durian,

    pub fn @"static call showAll"(self: *Static) void {
        const en = @typeInfo(@This()).@"enum";
        inline for (en.field_names, en.field_values, 0..) |name, value, i| {
            php.print("Fruit #{d}: {s}{s}\n", .{
                value + 1,
                name,
                if (self.special == i) " <-- special" else "",
            });
        }
        self.special += 1;
        if (self.special >= en.field_names.len) self.special = 0;
    }

    const Static = struct {
        special: usize = 1,
    };
};
pub const @"export Fruit" = php.Enum.Custom(Fruit);
