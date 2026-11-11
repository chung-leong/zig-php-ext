const php = @import("php/root.zig");

pub fn @"call factorial"(_: *@This(), args: struct {
    number: u64,
}) !u64 {
    var result: u64 = 1;
    for (1..args.number + 1) |i| {
        result, const overflow = @mulWithOverflow(result, i);
        if (overflow != 0) return error.TooLarge;
    }
    return result;
}
