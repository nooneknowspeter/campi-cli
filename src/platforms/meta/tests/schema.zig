const STD = @import("std");

const SCHEMA = @import("../schema.zig");

test "decode campaigns" {
    const fixture =
        \\{"data": [
        \\  {"id": "23840000000000", "name": "campi test", "status": "ACTIVE", "objective": "OUTCOME_TRAFFIC"}
        \\]}
    ;

    const campaigns = try SCHEMA.decodeCampaigns(STD.testing.allocator, fixture);
    defer {
        for (campaigns.?) |campaign| {
            STD.testing.allocator.free(campaign.id);
            STD.testing.allocator.free(campaign.name);
            STD.testing.allocator.free(campaign.status);
            STD.testing.allocator.free(campaign.objective);
        }
        STD.testing.allocator.free(campaigns.?);
    }

    try STD.testing.expectEqual(@as(usize, 1), campaigns.?.len);
    try STD.testing.expectEqualStrings("campi test", campaigns.?[0].name);
    try STD.testing.expectEqualStrings("23840000000000", campaigns.?[0].id);
    try STD.testing.expectEqualStrings("OUTCOME_TRAFFIC", campaigns.?[0].objective);
}
