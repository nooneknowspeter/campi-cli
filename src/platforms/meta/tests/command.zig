const STD = @import("std");

const META = @import("../main.zig");
const MODULE = @import("../command.zig");

test "formatCampaigns renders dollars with two decimals" {
    const CAMPAIGNS = [_]META.Campaign{
        .{ .name = "Spring Sale", .status = "ACTIVE", .objective = "OUTCOME_TRAFFIC", .daily_budget = "10000" },
        .{ .name = "Summer", .status = "PAUSED", .objective = "OUTCOME_LEADS", .daily_budget = "12345" },
    };

    var writer = STD.Io.Writer.Allocating.init(STD.testing.allocator);
    defer writer.deinit();

    try MODULE.formatCampaigns(&writer.writer, STD.testing.allocator, &CAMPAIGNS);

    const OUTPUT = try writer.toOwnedSlice();
    defer STD.testing.allocator.free(OUTPUT);

    try STD.testing.expectEqualStrings(
        "Spring Sale [TRAFFIC] ACTIVE $100.00\nSummer [LEADS] PAUSED $123.45\n",
        OUTPUT,
    );
}
