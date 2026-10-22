const STD = @import("std");

const SCHEMA = @import("../schema.zig");

test "decode account" {
    const fixture =
        \\{"results": [
        \\  {"customer": {"id": "123", "descriptiveName": "Campi"}}
        \\]}
    ;

    const account = try SCHEMA.decodeAccount(STD.testing.allocator, fixture);
    defer SCHEMA.freeAccount(STD.testing.allocator, account.?);

    try STD.testing.expectEqualStrings("123", account.?.id);
    try STD.testing.expectEqualStrings("Campi", account.?.name);
}

test "decode account returns null when none is found" {
    const fixture = "{\"results\": []}";

    const account = try SCHEMA.decodeAccount(STD.testing.allocator, fixture);

    try STD.testing.expectEqual(@as(?SCHEMA.ACCOUNT, null), account);
}

test "decode campaigns" {
    const fixture =
        \\{"results": [
        \\  {"campaign": {"id": "1", "name": "Spring Sale", "status": "PAUSED", "advertisingChannelType": "DISPLAY"}}
        \\]}
    ;

    const campaigns = try SCHEMA.decodeCampaigns(STD.testing.allocator, fixture);
    defer SCHEMA.freeCampaigns(STD.testing.allocator, campaigns.?);

    try STD.testing.expectEqual(@as(usize, 1), campaigns.?.len);
    try STD.testing.expectEqualStrings("1", campaigns.?[0].id);
    try STD.testing.expectEqualStrings("Spring Sale", campaigns.?[0].name);
    try STD.testing.expectEqualStrings("PAUSED", campaigns.?[0].status);
    try STD.testing.expectEqualStrings("DISPLAY", campaigns.?[0].channel_type);
}

test "decode ad groups extracts the campaign id" {
    const fixture =
        \\{"results": [
        \\  {"adGroup": {"id": "10", "name": "Prospecting", "status": "ENABLED", "campaign": "customers/123/campaigns/1"}}
        \\]}
    ;

    const ad_groups = try SCHEMA.decodeAdGroups(STD.testing.allocator, fixture);
    defer SCHEMA.freeAdGroups(STD.testing.allocator, ad_groups.?);

    try STD.testing.expectEqual(@as(usize, 1), ad_groups.?.len);
    try STD.testing.expectEqualStrings("10", ad_groups.?[0].id);
    try STD.testing.expectEqualStrings("1", ad_groups.?[0].campaign_id);
}

test "decode ads extracts the ad group id and keeps a blank name" {
    const fixture =
        \\{"results": [
        \\  {"adGroupAd": {"ad": {"id": "100", "name": "", "type": "RESPONSIVE_DISPLAY_AD"}, "adGroup": "customers/123/adGroups/10", "status": "ENABLED"}}
        \\]}
    ;

    const ads = try SCHEMA.decodeAds(STD.testing.allocator, fixture);
    defer SCHEMA.freeAds(STD.testing.allocator, ads.?);

    try STD.testing.expectEqual(@as(usize, 1), ads.?.len);
    try STD.testing.expectEqualStrings("100", ads.?[0].id);
    try STD.testing.expectEqualStrings("", ads.?[0].name);
    try STD.testing.expectEqualStrings("RESPONSIVE_DISPLAY_AD", ads.?[0].ad_type);
    try STD.testing.expectEqualStrings("10", ads.?[0].ad_group_id);
}

test "decode campaigns returns an empty list when none are found" {
    const fixture = "{\"results\": []}";

    const campaigns = try SCHEMA.decodeCampaigns(STD.testing.allocator, fixture);
    defer SCHEMA.freeCampaigns(STD.testing.allocator, campaigns.?);

    try STD.testing.expectEqual(@as(usize, 0), campaigns.?.len);
}

test "resourceId returns the trailing id" {
    try STD.testing.expectEqualStrings(
        "1",
        SCHEMA.resourceId("customers/123/campaigns/1"),
    );
    try STD.testing.expectEqualStrings("1", SCHEMA.resourceId("1"));
}
