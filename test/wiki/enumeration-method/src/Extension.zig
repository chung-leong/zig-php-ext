const php = @import("php/root.zig");

const Fruit = enum {
    apple,
    banana,
    cherry,
    durian,

    pub fn @"call show"(self: @This()) void {
        php.print("Fruit #{d}: {s}\n", .{ @backingInt(self) + 1, @tagName(self) });
    }

    pub fn @"static call showAll"(_: *Static) void {
        const en = @typeInfo(@This()).@"enum";
        inline for (en.field_names, en.field_values) |name, value| {
            php.print("Fruit #{d}: {s}\n", .{ value + 1, name });
        }
    }

    const Static = struct {};
};
pub const @"export Fruit" = php.Enum.Custom(Fruit);
