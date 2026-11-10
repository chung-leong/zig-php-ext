const php = @import("php/root.zig");

const Person = struct {
    name: []const u8,
    profession: []const u8,
    age: u16,
};

pub fn @"call show"(_: *@This(), args: struct {
    person: Person,
}) !void {
    php.print("Name: {s}\nProfession: {s}\nAge: {d}\n", .{
        args.person.name,
        args.person.profession,
        args.person.age,
    });
}
