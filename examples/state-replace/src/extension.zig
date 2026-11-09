const std = @import("std");

const ComptimeReplacer = @import("gemini.zig").ComptimeReplacer;
const php = @import("php/root.zig");

pub fn @"call replace_states"(_: *@This(), allocator: std.mem.Allocator, args: struct {
    text: []const u8,
    replacements: StateReplacements,
}) ![]const u8 {
    const replacer: ComptimeReplacer(StateReplacements) = .init(args.replacements);
    return replacer.replace(allocator, args.text);
}

const StateReplacements = init: {
    const field_types: [states.len]type = @splat([]const u8);
    const field_attributes: [states.len]std.lang.Type.Struct.FieldAttributes = @splat(.{});
    break :init @Struct(.auto, null, &states, &field_types, &field_attributes);
};

const states = [_][]const u8{
    "Alabama",
    "Alaska",
    "Arizona",
    "Arkansas",
    "California",
    "Colorado",
    "Connecticut",
    "Delaware",
    "Florida",
    "Georgia",
    "Hawaii",
    "Idaho",
    "Illinois",
    "Indiana",
    "Iowa",
    "Kansas",
    "Kentucky",
    "Louisiana",
    "Maine",
    "Maryland",
    "Massachusetts",
    "Michigan",
    "Minnesota",
    "Mississippi",
    "Missouri",
    "Montana",
    "Nebraska",
    "Nevada",
    "New Hampshire",
    "New Jersey",
    "New Mexico",
    "New York",
    "North Carolina",
    "North Dakota",
    "Ohio",
    "Oklahoma",
    "Oregon",
    "Pennsylvania",
    "Rhode Island",
    "South Carolina",
    "South Dakota",
    "Tennessee",
    "Texas",
    "Utah",
    "Vermont",
    "Virginia",
    "Washington",
    "West Virginia",
    "Wisconsin",
    "Wyoming",
};
