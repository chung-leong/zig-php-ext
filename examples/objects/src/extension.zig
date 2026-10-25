const php = @import("php/root.zig");

const Power = enum { tech, mutant, occult, alien, training };

const Avenger = struct {
    real_name: []const u8,
    superhero_name: []const u8,
    power: Power = .training,
};

pub const @"export Power" = Power;

pub fn @"call assemble"(_: *@This(), args: struct {
    avengers: []Avenger,
}) !void {
    for (args.avengers) |a| {
        php.print("{s} = {s} ({})\n", .{ a.superhero_name, a.real_name, a.power });
    }
}
