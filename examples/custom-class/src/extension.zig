const std = @import("std");

const php = @import("php/root.zig");
const getter = php.Object.getter;
const setter = php.Object.setter;

pub const @"export marvel\\Avenger" = php.Class.Custom(struct {
    pub const @"export Power" = Power;

    pub const @"get real_name" = getter(@This(), .real_name);
    pub const @"set real_name" = setter(@This(), .real_name);
    pub const @"get superhero_name" = getter(@This(), .superhero_name);
    pub const @"set superhero_name" = setter(@This(), .superhero_name);

    pub fn @"get power"(self: *@This()) *php.String {
        return switch (self.power) {
            inline else => |tag| php.String.static(@tagName(tag)),
        };
    }

    pub fn @"set power"(self: *@This(), name: *php.String) !void {
        self.power = inline for (comptime std.meta.fieldNames(Power)) |field_name| {
            if (name.matchStatic(field_name)) break @field(Power, field_name);
        } else return error.InvalidPower;
    }

    pub fn @"call show"(self: *@This(), _: struct {}) !void {
        php.print("{s} = {s} ({})\n", .{
            self.superhero_name,
            self.real_name,
            self.power,
        });
    }

    const Power = enum { tech, mutant, occult, alien, training };

    real_name: []const u8 = "",
    superhero_name: []const u8 = "",
    power: Power = .training,
});
