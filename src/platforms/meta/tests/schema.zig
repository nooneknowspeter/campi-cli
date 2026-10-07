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

test "decode instagram accounts" {
    const fixture =
        \\{"data": [
        \\  {"id": "17841400000000000", "ig_id": "17841400000000001", "username": "campi", "name": "Campi"}
        \\]}
    ;

    const accounts = try SCHEMA.decodeInstagramAccounts(STD.testing.allocator, fixture);
    defer freeInstagramAccounts(accounts.?);

    try STD.testing.expectEqual(@as(usize, 1), accounts.?.len);
    try STD.testing.expectEqualStrings("17841400000000000", accounts.?[0].id);
    try STD.testing.expectEqualStrings("17841400000000001", accounts.?[0].ig_id.?);
    try STD.testing.expectEqualStrings("campi", accounts.?[0].username.?);
    try STD.testing.expectEqualStrings("Campi", accounts.?[0].name.?);
}

test "decode instagram accounts returns an empty list when none are linked" {
    const fixture = "{\"data\": []}";

    const accounts = try SCHEMA.decodeInstagramAccounts(STD.testing.allocator, fixture);
    defer freeInstagramAccounts(accounts.?);

    try STD.testing.expectEqual(@as(usize, 0), accounts.?.len);
}

test "decode instagram accounts tolerates missing optional fields" {
    const fixture = "{\"data\": [{\"id\": \"17841400000000000\"}]}";

    const accounts = try SCHEMA.decodeInstagramAccounts(STD.testing.allocator, fixture);
    defer freeInstagramAccounts(accounts.?);

    try STD.testing.expectEqual(@as(usize, 1), accounts.?.len);
    try STD.testing.expectEqual(@as(?[]const u8, null), accounts.?[0].ig_id);
    try STD.testing.expectEqual(@as(?[]const u8, null), accounts.?[0].username);
    try STD.testing.expectEqual(@as(?[]const u8, null), accounts.?[0].name);
}

fn freeInstagramAccounts(accounts: []SCHEMA.INSTAGRAM_ACCOUNT) void {
    for (accounts) |account| {
        STD.testing.allocator.free(account.id);
        if (account.ig_id) |ig_id| STD.testing.allocator.free(ig_id);
        if (account.username) |username| STD.testing.allocator.free(username);
        if (account.name) |name| STD.testing.allocator.free(name);
    }
    STD.testing.allocator.free(accounts);
}
