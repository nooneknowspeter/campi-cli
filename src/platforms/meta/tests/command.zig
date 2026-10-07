const STD = @import("std");

const CONTEXT = @import("../../../cli/context.zig");
const META = @import("../main.zig");
const MODULE = @import("../command.zig");

test "formatCampaigns strips the outcome prefix from objectives" {
    var stdin_reader = STD.Io.Reader.fixed(&.{});
    var stdout_writer = STD.Io.Writer.Allocating.init(STD.testing.allocator);
    var stderr_writer = STD.Io.Writer.Allocating.init(STD.testing.allocator);

    const COMMAND_CONTEXT = CONTEXT.CommandContext{
        .stdin = &stdin_reader,
        .stdout = &stdout_writer.writer,
        .stderr = &stderr_writer.writer,
        .io = STD.testing.io,
    };

    const CAMPAIGNS = [_]META.Campaign{
        .{ .name = "Spring Sale", .status = "ACTIVE", .objective = "OUTCOME_TRAFFIC" },
        .{ .name = "Summer", .status = "PAUSED", .objective = "OUTCOME_LEADS" },
        .{ .name = "Evergreen", .status = "ACTIVE", .objective = "REACH" },
    };

    try MODULE.formatCampaigns(COMMAND_CONTEXT, &CAMPAIGNS);

    var stdout_output = stdout_writer.toArrayList();
    defer stdout_output.deinit(STD.testing.allocator);

    try STD.testing.expectEqualStrings(
        "Spring Sale [TRAFFIC] ACTIVE\nSummer [LEADS] PAUSED\nEvergreen [REACH] ACTIVE\n",
        stdout_output.items,
    );
}

test "formatInstagramAccounts prints identifiers and hides a matching ig id" {
    var stdin_reader = STD.Io.Reader.fixed(&.{});
    var stdout_writer = STD.Io.Writer.Allocating.init(STD.testing.allocator);
    var stderr_writer = STD.Io.Writer.Allocating.init(STD.testing.allocator);

    const COMMAND_CONTEXT = CONTEXT.CommandContext{
        .stdin = &stdin_reader,
        .stdout = &stdout_writer.writer,
        .stderr = &stderr_writer.writer,
        .io = STD.testing.io,
    };

    const ACCOUNTS = [_]META.INSTAGRAM_ACCOUNT{
        .{ .id = "17841400000000000", .username = "campi", .name = "Campi" },
        .{ .id = "42", .ig_id = "99" },
        .{ .id = "43", .ig_id = "43" },
    };

    try MODULE.formatInstagramAccounts(COMMAND_CONTEXT, &ACCOUNTS);

    var stdout_output = stdout_writer.toArrayList();
    defer stdout_output.deinit(STD.testing.allocator);

    try STD.testing.expectEqualStrings(
        \\Linked instagram accounts:
        \\  Campi (@campi) id=17841400000000000
        \\  id=42 ig_id=99
        \\  id=43
        \\
    , stdout_output.items);
}

test "formatInstagramAccounts reports when nothing is linked" {
    var stdin_reader = STD.Io.Reader.fixed(&.{});
    var stdout_writer = STD.Io.Writer.Allocating.init(STD.testing.allocator);
    var stderr_writer = STD.Io.Writer.Allocating.init(STD.testing.allocator);

    const COMMAND_CONTEXT = CONTEXT.CommandContext{
        .stdin = &stdin_reader,
        .stdout = &stdout_writer.writer,
        .stderr = &stderr_writer.writer,
        .io = STD.testing.io,
    };

    const ACCOUNTS: []const META.INSTAGRAM_ACCOUNT = &.{};

    try MODULE.formatInstagramAccounts(COMMAND_CONTEXT, ACCOUNTS);

    var stdout_output = stdout_writer.toArrayList();
    defer stdout_output.deinit(STD.testing.allocator);

    try STD.testing.expectEqualStrings(
        \\Linked instagram accounts:
        \\  none found
        \\
    , stdout_output.items);
}
