const STD = @import("std");

const MODULE = @import("../command.zig");
const SCHEMA = @import("../schema.zig");

test "printTree renders the inventory" {
    var stdout_writer = STD.Io.Writer.Allocating.init(STD.testing.allocator);

    const CAMPAIGNS = [_]SCHEMA.CAMPAIGN{
        .{ .id = "1", .name = "Spring Sale", .status = "ENABLED", .channel_type = "DISPLAY" },
        .{ .id = "2", .name = "Evergreen", .status = "PAUSED", .channel_type = "SEARCH" },
    };

    const AD_GROUPS = [_]SCHEMA.AD_GROUP{
        .{ .id = "10", .name = "Prospecting", .status = "ENABLED", .campaign_id = "1" },
        .{ .id = "11", .name = "Retargeting", .status = "PAUSED", .campaign_id = "1" },
    };

    const ADS = [_]SCHEMA.AD{
        .{ .id = "100", .name = "Responsive ad", .ad_type = "RESPONSIVE_DISPLAY_AD", .ad_group_id = "10", .status = "ENABLED" },
        .{ .id = "101", .name = "", .ad_type = "DISPLAY", .ad_group_id = "11", .status = "PAUSED" },
    };

    try MODULE.printTree(
        &stdout_writer.writer,
        "Campi",
        "123",
        &CAMPAIGNS,
        &AD_GROUPS,
        &ADS,
    );

    var stdout_output = stdout_writer.toArrayList();
    defer stdout_output.deinit(STD.testing.allocator);

    try STD.testing.expectEqualStrings(
        \\Account: Campi (123)
        \\|- Campaigns
        \\|  |- Spring Sale [DISPLAY] ENABLED
        \\|  |  |- Prospecting [ENABLED]
        \\|  |  |  |- Responsive ad [ENABLED]
        \\|  |  |- Retargeting [PAUSED]
        \\|  |  |  |- DISPLAY [PAUSED]
        \\|  |- Evergreen [SEARCH] PAUSED
        \\
    , stdout_output.items);
}

test "printTree reports an empty inventory" {
    var stdout_writer = STD.Io.Writer.Allocating.init(STD.testing.allocator);

    try MODULE.printTree(
        &stdout_writer.writer,
        "",
        "123",
        &.{},
        &.{},
        &.{},
    );

    var stdout_output = stdout_writer.toArrayList();
    defer stdout_output.deinit(STD.testing.allocator);

    try STD.testing.expectEqualStrings(
        \\Account: Unknown (123)
        \\|- Campaigns
        \\|  - none found
        \\
    , stdout_output.items);
}
