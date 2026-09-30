const STD = @import("std");

const META = @import("../main.zig");
const MODULE = @import("../command.zig");

test "formatCampaigns strips the outcome prefix from objectives" {
    const CAMPAIGNS = [_]META.Campaign{
        .{ .name = "Spring Sale", .status = "ACTIVE", .objective = "OUTCOME_TRAFFIC" },
        .{ .name = "Summer", .status = "PAUSED", .objective = "OUTCOME_LEADS" },
        .{ .name = "Evergreen", .status = "ACTIVE", .objective = "REACH" },
    };

    var writer = STD.Io.Writer.Allocating.init(STD.testing.allocator);
    defer writer.deinit();

    try MODULE.formatCampaigns(&writer.writer, &CAMPAIGNS);

    const OUTPUT = try writer.toOwnedSlice();
    defer STD.testing.allocator.free(OUTPUT);

    try STD.testing.expectEqualStrings(
        "Spring Sale [TRAFFIC] ACTIVE\nSummer [LEADS] PAUSED\nEvergreen [REACH] ACTIVE\n",
        OUTPUT,
    );
}
