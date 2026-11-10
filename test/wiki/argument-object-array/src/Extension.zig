const php = @import("php/root.zig");

const Person = struct {
    name: []const u8,
    profession: []const u8,
    age: u16,
};

pub fn @"call show"(_: *@This(), args: struct {
    persons: []Person,
}) !void {
    for (args.persons, 0..) |person, i| {
        php.print("#{d}.\nName: {s}\nProfession: {s}\nAge: {d}\n", .{
            i + 1,
            person.name,
            person.profession,
            person.age,
        });
    }
}
