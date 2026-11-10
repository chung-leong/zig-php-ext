const php = @import("php/root.zig");

const Cat = struct {
    pub fn say(_: *@This()) void {
        php.print("meow\n", .{});
    }
};
const Dog = struct {
    pub fn say(_: *@This()) void {
        php.print("woof\n", .{});
    }
};
const Fox = struct {
    pub fn say(_: *@This()) void {
        php.print("????\n", .{});
    }
};

pub const @"export Cat" = php.Class.Custom(Cat);
pub const @"export Dog" = php.Class.Custom(Dog);
pub const @"export Fox" = php.Class.Custom(Fox);

pub fn @"call poke"(_: *@This(), args: struct {
    animal: union(enum) {
        cat: *Cat,
        dog: *Dog,
        fox: *Fox,
    },
}) !void {
    switch (args.animal) {
        inline else => |animal, tag| {
            php.print("{s}: ", .{@tagName(tag)});
            animal.say();
        },
    }
}
