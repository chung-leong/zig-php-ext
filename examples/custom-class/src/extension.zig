const std = @import("std");

const php = @import("php/root.zig");
const getter = php.Object.getter;
const setter = php.Object.setter;

pub const @"export marvel\\Avenger" = php.Class.Custom(Avenger);

const Avenger = struct {
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

    pub fn @"call show"(self: *@This()) void {
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
};

pub fn @"call assemble"(_: *@This(), args: struct {
    avengers: []*Avenger,
}) void {
    for (args.avengers) |avenger| avenger.@"call show"(.{});
}

pub fn @"call same"(_: *@This(), args: struct {
    avenger: *Avenger,
}) *php.Object {
    const object = php.Object.fromCustom(args.avenger);
    return object.retain();
}

pub fn @"call make_worthy"(_: *@This(), args: struct {
    real_name: []const u8,
}) !*php.Object {
    const avenger: Avenger = .{
        .superhero_name = try php.allocator.dupe(u8, "Thor"),
        .real_name = try php.allocator.dupe(u8, args.real_name),
        .power = .alien,
    };
    return .createCustom(Avenger, avenger);
}
