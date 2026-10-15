const STD = @import("std");

const META = @import("../main.zig");
const MODULE = @import("../command.zig");
const SCHEMA = @import("../schema.zig");

test "printTree renders the inventory and strips the outcome prefix" {
    var stdout_writer = STD.Io.Writer.Allocating.init(STD.testing.allocator);

    const PAGES = [_]SCHEMA.PAGE{
        .{ .id = "1443546992166726", .name = "Campi hq" },
    };

    const INSTAGRAM = [_]META.INSTAGRAM_ACCOUNT{
        .{ .id = "17841400000000000", .username = "campi", .name = "Campi" },
        .{ .id = "42", .ig_id = "99" },
    };

    const CAMPAIGNS = [_]SCHEMA.CAMPAIGN{
        .{ .id = "1", .name = "Spring Sale", .status = "ACTIVE", .objective = "OUTCOME_TRAFFIC" },
        .{ .id = "2", .name = "Evergreen", .status = "ACTIVE", .objective = "REACH" },
    };

    const AD_SETS = [_]SCHEMA.AD_SET{
        .{ .id = "10", .name = "Prospecting", .campaign_id = "1", .status = "ACTIVE" },
        .{ .id = "11", .name = "Retargeting", .campaign_id = "1", .status = "PAUSED" },
        .{ .id = "12", .name = "Other", .campaign_id = "2", .status = "ACTIVE" },
    };

    const ADS = [_]SCHEMA.AD{
        .{ .id = "100", .name = "Image ad one", .ad_set_id = "10", .status = "ACTIVE" },
        .{ .id = "101", .name = "Image ad two", .ad_set_id = "10", .status = "PAUSED" },
        .{ .id = "102", .name = "Unrelated", .ad_set_id = "999", .status = "ACTIVE" },
    };

    try MODULE.printTree(
        &stdout_writer.writer,
        "campi",
        "1641450320851401",
        &PAGES,
        &INSTAGRAM,
        &CAMPAIGNS,
        &AD_SETS,
        &ADS,
    );

    var stdout_output = stdout_writer.toArrayList();
    defer stdout_output.deinit(STD.testing.allocator);

    try STD.testing.expectEqualStrings(
        \\Account: campi (act_1641450320851401)
        \\|- Pages
        \\|  |- Campi hq [1443546992166726]
        \\|- Instagram accounts
        \\|  |- Campi (@campi) id=17841400000000000
        \\|  |- id=42 ig_id=99
        \\|- Campaigns
        \\|  |- Spring Sale [TRAFFIC] ACTIVE
        \\|  |  |- Prospecting [ACTIVE]
        \\|  |  |  |- Image ad one [ACTIVE]
        \\|  |  |  |- Image ad two [PAUSED]
        \\|  |  |- Retargeting [PAUSED]
        \\|  |- Evergreen [REACH] ACTIVE
        \\|  |  |- Other [ACTIVE]
        \\
    , stdout_output.items);
}

test "printTree reports empty sections when nothing is found" {
    var stdout_writer = STD.Io.Writer.Allocating.init(STD.testing.allocator);

    try MODULE.printTree(
        &stdout_writer.writer,
        "campi",
        "1641450320851401",
        &.{},
        &.{},
        &.{},
        &.{},
        &.{},
    );

    var stdout_output = stdout_writer.toArrayList();
    defer stdout_output.deinit(STD.testing.allocator);

    try STD.testing.expectEqualStrings(
        \\Account: campi (act_1641450320851401)
        \\|- Pages
        \\|  - none found
        \\|- Instagram accounts
        \\|  - none found
        \\|- Campaigns
        \\|  - none found
        \\
    , stdout_output.items);
}
