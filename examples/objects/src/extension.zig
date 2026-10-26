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

pub fn @"call get"(_: *@This(), _: struct {}) !Avenger {
    return .{
        .superhero_name = "Captain America",
        .real_name = "Steve Rogers",
    };
}

pub fn @"call get_two"(_: *@This(), _: struct {}) ![2]Avenger {
    return .{
        .{
            .superhero_name = "Captain America",
            .real_name = "Steve Rogers",
        },
        .{
            .superhero_name = "Ironman",
            .real_name = "Tony Stark",
            .power = .tech,
        },
    };
}

pub fn @"call get_multiple"(_: *@This(), args: struct {
    count: usize,
}) !*php.Array {
    const array: *php.Array = .create();
    for (0..args.count) |_| {
        array.append(.fromAny(.{
            .superhero_name = "Multiple Man",
            .real_name = "Jamie Madrox",
        }));
    }
    return array;
}
