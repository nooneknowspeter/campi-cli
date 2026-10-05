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
