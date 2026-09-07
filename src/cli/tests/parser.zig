const STD = @import("std");

const PARSER = @import("../parser.zig");

const TEST_DEFINITIONS = [_]PARSER.FlagDefinition{
    .{
        .long_flag = "verbose",
        .short_flag = 'v',
        .is_flag_a_boolean = true,
        .description = "Show verbose output",
    },
    .{
        .long_flag = "dir",
        .short_flag = 'd',
        .is_flag_a_boolean = false,
        .description = "Run in the specified working directory",
    },
};

test "check if a single long flag is resolved" {
    var arena = STD.heap.ArenaAllocator.init(STD.testing.allocator);
    defer arena.deinit();

    const ARGS = [_][]const u8{"--verbose"};
    const RESOLUTION = try PARSER.resolveFlags(arena.allocator(), &TEST_DEFINITIONS, &ARGS);

    try STD.testing.expect(RESOLUTION.failure == null);
    try STD.testing.expectEqual(@as(usize, 1), RESOLUTION.flags.len);
    try STD.testing.expectEqualStrings("verbose", RESOLUTION.flags[0].long_flag);
    try STD.testing.expectEqual(@as(?u8, 'v'), RESOLUTION.flags[0].short_flag);
    try STD.testing.expect(RESOLUTION.flags[0].is_value_included == false);
}

test "check if a short flag is resolved" {
    var arena = STD.heap.ArenaAllocator.init(STD.testing.allocator);
    defer arena.deinit();

    const ARGS = [_][]const u8{"-v"};
    const RESOLUTION = try PARSER.resolveFlags(arena.allocator(), &TEST_DEFINITIONS, &ARGS);

    try STD.testing.expect(RESOLUTION.failure == null);
    try STD.testing.expectEqual(@as(usize, 1), RESOLUTION.flags.len);
    try STD.testing.expectEqualStrings("verbose", RESOLUTION.flags[0].long_flag);
}

test "check if an inline value flag resolves with the value included" {
    var arena = STD.heap.ArenaAllocator.init(STD.testing.allocator);
    defer arena.deinit();

    const ARGS = [_][]const u8{"--dir=/tmp/work"};
    const RESOLUTION = try PARSER.resolveFlags(arena.allocator(), &TEST_DEFINITIONS, &ARGS);

    try STD.testing.expect(RESOLUTION.failure == null);
    try STD.testing.expectEqual(@as(usize, 1), RESOLUTION.flags.len);
    try STD.testing.expect(RESOLUTION.flags[0].is_value_included == true);
    try STD.testing.expectEqualStrings("/tmp/work", RESOLUTION.flags[0].value.?);
}

test "check if a value flag consumes the following argument" {
    var arena = STD.heap.ArenaAllocator.init(STD.testing.allocator);
    defer arena.deinit();

    const ARGS = [_][]const u8{ "--dir", "/tmp/work" };
    const RESOLUTION = try PARSER.resolveFlags(arena.allocator(), &TEST_DEFINITIONS, &ARGS);

    try STD.testing.expect(RESOLUTION.failure == null);
    try STD.testing.expectEqual(@as(usize, 1), RESOLUTION.flags.len);
    try STD.testing.expect(RESOLUTION.flags[0].is_value_included == false);
    try STD.testing.expectEqualStrings("/tmp/work", RESOLUTION.flags[0].value.?);
}

test "ensure an unknown flag fails with unknown_flag" {
    var arena = STD.heap.ArenaAllocator.init(STD.testing.allocator);
    defer arena.deinit();

    const ARGS = [_][]const u8{"--wat"};
    const RESOLUTION = try PARSER.resolveFlags(arena.allocator(), &TEST_DEFINITIONS, &ARGS);

    try STD.testing.expectEqual(
        PARSER.ResolutionFailure{ .unknown_flag = "--wat" },
        RESOLUTION.failure.?,
    );
    try STD.testing.expectEqual(@as(usize, 0), RESOLUTION.flags.len);
}

test "ensure a missing value fails with invalid_value" {
    var arena = STD.heap.ArenaAllocator.init(STD.testing.allocator);
    defer arena.deinit();

    const ARGS = [_][]const u8{"--dir"};
    const RESOLUTION = try PARSER.resolveFlags(arena.allocator(), &TEST_DEFINITIONS, &ARGS);

    try STD.testing.expectEqual(
        PARSER.ResolutionFailure{ .invalid_value = "--dir" },
        RESOLUTION.failure.?,
    );
}

test "ensure a value that looks like a flag fails with invalid_value" {
    var arena = STD.heap.ArenaAllocator.init(STD.testing.allocator);
    defer arena.deinit();

    const ARGS = [_][]const u8{ "--dir", "--verbose" };
    const RESOLUTION = try PARSER.resolveFlags(arena.allocator(), &TEST_DEFINITIONS, &ARGS);

    try STD.testing.expectEqual(
        PARSER.ResolutionFailure{ .invalid_value = "--dir" },
        RESOLUTION.failure.?,
    );
}
