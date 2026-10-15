const STD = @import("std");

const CONFIG = @import("../../config/main.zig");
const MANIFEST = @import("../../manifest/main.zig");
const PLAN = @import("../main.zig");

test "computePlan reports a platform enabled in a manifest but not configured" {
    var arena = STD.heap.ArenaAllocator.init(STD.testing.allocator);
    defer arena.deinit();

    const ALLOCATOR = arena.allocator();

    const CONFIG_VALUE = CONFIG.SCHEMA.CONFIG{
        .campi_version = "0.0.0",
        .config_version = "0.1.0",
        .project_name = "test",
        .state_file_location_type = .local,
        .state_file_uri = "state.campi",
        .platform_configs = .{
            .meta = null,
            .x = null,
            .tiktok = null,
            .google = null,
            .reddit = null,
            .linkedin = null,
        },
        .manifest_files = .{ .manifest_files = &.{"test.manifest.campi"} },
    };

    var campaigns = [_]MANIFEST.SCHEMA.CAMPAIGN{};
    const MANIFESTS = [_]MANIFEST.LoadedManifest{
        .{
            .file_path = "test.manifest.campi",
            .source = "",
            .value = .{
                .campaigns = &campaigns,
                .platforms = .{
                    .meta = true,
                    .x = null,
                    .tiktok = null,
                    .google = null,
                    .reddit = null,
                    .linkedin = null,
                },
            },
        },
    };

    const PLAN_VALUE = try PLAN.computePlan(ALLOCATOR, CONFIG_VALUE, &MANIFESTS, null);

    try STD.testing.expectEqual(@as(usize, 0), PLAN_VALUE.operations.len);
    try STD.testing.expectEqual(@as(usize, 1), PLAN_VALUE.unconfigured_platforms.len);
    try STD.testing.expectEqualStrings("meta", PLAN_VALUE.unconfigured_platforms[0]);
}

test "printTree renders each operation with its ad groups and ads" {
    var writer = STD.Io.Writer.Allocating.init(STD.testing.allocator);

    var ad_group_names = [_][]const u8{"Demo ad set"};

    var ads = [_]MANIFEST.SCHEMA.AD{
        .{
            .name = "Demo ad",
            .status = .PAUSED,
            .target = null,
            .CREATIVE = .{
                .media_type = .IMAGE,
                .headline = "Demo headline",
                .body_text = "Demo body text",
                .call_to_action = .LEARN_MORE,
                .media_urls = &.{},
                .destination_url = "https://example.com",
                .display_url = null,
            },
            .tracking = null,
        },
    };

    var ad_groups = [_]MANIFEST.SCHEMA.AD_GROUP{
        .{
            .name = &ad_group_names,
            .status = .PAUSED,
            .budget = null,
            .target = null,
            .optimization_goal = .CLICKS,
            .bid_amount_in_cents = null,
            .ads = &ads,
        },
    };

    var campaigns = [_]MANIFEST.SCHEMA.CAMPAIGN{
        .{
            .name = "Demo campaign",
            .objective = .TRAFFIC,
            .status = .PAUSED,
            .budget = null,
            .ad_groups = &ad_groups,
        },
    };

    const MANIFESTS = [_]MANIFEST.LoadedManifest{
        .{
            .file_path = "demo.manifest.campi",
            .source = "",
            .value = .{
                .campaigns = &campaigns,
                .platforms = .{
                    .meta = true,
                    .x = null,
                    .tiktok = null,
                    .google = null,
                    .reddit = null,
                    .linkedin = null,
                },
            },
        },
    };

    const OPERATIONS = [_]PLAN.SCHEMA.OPERATION{
        .{
            .platform = "meta",
            .campaign = "Demo campaign",
            .operation_type = .create,
            .external_id = null,
            .input_manifest = "demo.manifest.campi",
            .manifest_hash = "abc123",
        },
        .{
            .platform = "meta",
            .campaign = "Old campaign",
            .operation_type = .archive,
            .external_id = "1234567890",
            .input_manifest = "demo.manifest.campi",
            .manifest_hash = "",
        },
    };

    try PLAN.printTree(&writer.writer, &OPERATIONS, &MANIFESTS);

    var output = writer.toArrayList();
    defer output.deinit(STD.testing.allocator);

    try STD.testing.expectEqualStrings(
        \\meta: 2 change(s)
        \\|- + Demo campaign [TRAFFIC] PAUSED
        \\|  |- + Demo ad set [PAUSED]
        \\|  |  |- + Demo ad [PAUSED]
        \\|- - Old campaign
        \\
    , output.items);
}
