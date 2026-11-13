const php = @import("php/root.zig");

const Fruit = enum {
    apple,
    banana,
    cherry,
    durian,

    pub fn @"call show"(self: @This()) void {
        php.print("Fruit #{d}: {s}\n", .{ @backingInt(self) + 1, @tagName(self) });
    }
};
pub const @"export Fruit" = php.Enum.Custom(Fruit);
