const php = @import("php/root.zig");

const Power = enum { tech, mutant, occult, alien, training };

const Avenger = struct {
    real_name: []const u8,
    superhero_name: []const u8,
    power: Power = .training,
};

pub const @"export Power" = Power;

pub fn @"call show"(_: *@This(), args: struct {
    avenger: Avenger,
}) !void {
    php.print("{s} = {s} ({})\n", .{
        args.avenger.superhero_name,
        args.avenger.real_name,
        args.avenger.power,
    });
}

pub fn @"call assemble"(_: *@This(), args: struct {
    avengers: []Avenger,
}) !void {
    for (args.avengers) |a| {
        php.print("{s} = {s} ({})\n", .{
            a.superhero_name,
            a.real_name,
            a.power,
        });
    }
}
