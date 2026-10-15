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

test "decode ad sets" {
    const fixture =
        \\{"data": [
        \\  {"id": "10", "name": "Prospecting", "campaign_id": "1", "status": "ACTIVE"}
        \\]}
    ;

    const ad_sets = try SCHEMA.decodeAdSets(STD.testing.allocator, fixture);
    defer SCHEMA.freeAdSets(STD.testing.allocator, ad_sets.?);

    try STD.testing.expectEqual(@as(usize, 1), ad_sets.?.len);
    try STD.testing.expectEqualStrings("10", ad_sets.?[0].id);
    try STD.testing.expectEqualStrings("Prospecting", ad_sets.?[0].name);
    try STD.testing.expectEqualStrings("1", ad_sets.?[0].campaign_id);
    try STD.testing.expectEqualStrings("ACTIVE", ad_sets.?[0].status);
}

test "decode ads" {
    const fixture =
        \\{"data": [
        \\  {"id": "100", "name": "Image ad", "adset_id": "10", "status": "PAUSED"}
        \\]}
    ;

    const ads = try SCHEMA.decodeAds(STD.testing.allocator, fixture);
    defer SCHEMA.freeAds(STD.testing.allocator, ads.?);

    try STD.testing.expectEqual(@as(usize, 1), ads.?.len);
    try STD.testing.expectEqualStrings("100", ads.?[0].id);
    try STD.testing.expectEqualStrings("Image ad", ads.?[0].name);
    try STD.testing.expectEqualStrings("10", ads.?[0].ad_set_id);
    try STD.testing.expectEqualStrings("PAUSED", ads.?[0].status);
}

test "decode pages tolerates a missing category" {
    const fixture =
        \\{"data": [
        \\  {"id": "1443546992166726", "name": "Campi hq", "category": "Business"},
        \\  {"id": "2", "name": "No category"}
        \\]}
    ;

    const pages = try SCHEMA.decodePages(STD.testing.allocator, fixture);
    defer SCHEMA.freePages(STD.testing.allocator, pages.?);

    try STD.testing.expectEqual(@as(usize, 2), pages.?.len);
    try STD.testing.expectEqualStrings("1443546992166726", pages.?[0].id);
    try STD.testing.expectEqualStrings("Campi hq", pages.?[0].name);
    try STD.testing.expectEqualStrings("Business", pages.?[0].category.?);
    try STD.testing.expectEqual(@as(?[]const u8, null), pages.?[1].category);
}

fn freeInstagramAccounts(accounts: []SCHEMA.INSTAGRAM_ACCOUNT) void {
    SCHEMA.freeInstagramAccounts(STD.testing.allocator, accounts);
}
