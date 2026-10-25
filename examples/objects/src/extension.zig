const php = @import("php/root.zig");

const Avenger = struct {
    real_name: []const u8,
    superhero_name: []const u8,
};

pub fn @"call assemble"(_: *@This(), args: struct {
    avengers: []Avenger,
}) !void {
    for (args.avengers) |a| {
        php.print("{s} = {s}\n", .{ a.superhero_name, a.real_name });
    }
}
