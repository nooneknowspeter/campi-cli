const STD = @import("std");

pub const ACCOUNT = struct {
    id: []const u8,
    name: []const u8,
};

pub const CAMPAIGN = struct {
    id: []const u8,
    name: []const u8,
    status: []const u8,
    channel_type: []const u8,
};

pub const AD_GROUP = struct {
    id: []const u8,
    name: []const u8,
    status: []const u8,
    campaign_id: []const u8,
};

pub const AD = struct {
    id: []const u8,
    name: []const u8,
    ad_type: []const u8,
    ad_group_id: []const u8,
    status: []const u8,
};

pub fn resourceId(value: []const u8) []const u8 {
    const INDEX = STD.mem.lastIndexOfScalar(u8, value, '/') orelse return value;

    return value[INDEX + 1 ..];
}

pub fn decodeAccount(
    allocator: STD.mem.Allocator,
    document: []const u8,
) !?ACCOUNT {
    const PARSED = try STD.json.parseFromSlice(
        STD.json.Value,
        allocator,
        document,
        .{},
    );
    defer PARSED.deinit();

    const RESULTS = PARSED.value.object.get("results") orelse return null;
    if (RESULTS.array.items.len == 0) return null;

    const CUSTOMER_VALUE = RESULTS.array.items[0].object.get("customer") orelse
        return error.GoogleRequestFailed;
    const CUSTOMER = CUSTOMER_VALUE.object;

    return .{
        .id = try allocator.dupe(u8, stringValue(CUSTOMER, "id") orelse ""),
        .name = try allocator.dupe(u8, stringValue(CUSTOMER, "descriptiveName") orelse ""),
    };
}

pub fn decodeCampaigns(
    allocator: STD.mem.Allocator,
    document: []const u8,
) !?[]CAMPAIGN {
    const PARSED = try STD.json.parseFromSlice(
        STD.json.Value,
        allocator,
        document,
        .{},
    );
    defer PARSED.deinit();

    const RESULTS = PARSED.value.object.get("results") orelse return null;

    const ITEMS = try allocator.alloc(CAMPAIGN, RESULTS.array.items.len);

    for (RESULTS.array.items, 0..) |item, i| {
        const CAMPAIGN_VALUE = item.object.get("campaign") orelse
            return error.GoogleRequestFailed;
        const CAMPAIGN_OBJECT = CAMPAIGN_VALUE.object;

        ITEMS[i] = .{
            .id = try allocator.dupe(u8, stringValue(CAMPAIGN_OBJECT, "id") orelse ""),
            .name = try allocator.dupe(u8, stringValue(CAMPAIGN_OBJECT, "name") orelse ""),
            .status = try allocator.dupe(u8, stringValue(CAMPAIGN_OBJECT, "status") orelse ""),
            .channel_type = try allocator.dupe(
                u8,
                stringValue(CAMPAIGN_OBJECT, "advertisingChannelType") orelse "",
            ),
        };
    }

    return ITEMS;
}

pub fn decodeAdGroups(
    allocator: STD.mem.Allocator,
    document: []const u8,
) !?[]AD_GROUP {
    const PARSED = try STD.json.parseFromSlice(
        STD.json.Value,
        allocator,
        document,
        .{},
    );
    defer PARSED.deinit();

    const RESULTS = PARSED.value.object.get("results") orelse return null;

    const ITEMS = try allocator.alloc(AD_GROUP, RESULTS.array.items.len);

    for (RESULTS.array.items, 0..) |item, i| {
        const AD_GROUP_VALUE = item.object.get("adGroup") orelse
            return error.GoogleRequestFailed;
        const AD_GROUP_OBJECT = AD_GROUP_VALUE.object;

        ITEMS[i] = .{
            .id = try allocator.dupe(u8, stringValue(AD_GROUP_OBJECT, "id") orelse ""),
            .name = try allocator.dupe(u8, stringValue(AD_GROUP_OBJECT, "name") orelse ""),
            .status = try allocator.dupe(u8, stringValue(AD_GROUP_OBJECT, "status") orelse ""),
            .campaign_id = try allocator.dupe(
                u8,
                resourceId(stringValue(AD_GROUP_OBJECT, "campaign") orelse ""),
            ),
        };
    }

    return ITEMS;
}

pub fn decodeAds(
    allocator: STD.mem.Allocator,
    document: []const u8,
) !?[]AD {
    const PARSED = try STD.json.parseFromSlice(
        STD.json.Value,
        allocator,
        document,
        .{},
    );
    defer PARSED.deinit();

    const RESULTS = PARSED.value.object.get("results") orelse return null;

    const ITEMS = try allocator.alloc(AD, RESULTS.array.items.len);

    for (RESULTS.array.items, 0..) |item, i| {
        const AD_GROUP_AD_VALUE = item.object.get("adGroupAd") orelse
            return error.GoogleRequestFailed;
        const AD_GROUP_AD = AD_GROUP_AD_VALUE.object;
        const AD_VALUE = AD_GROUP_AD.get("ad") orelse
            return error.GoogleRequestFailed;
        const AD_OBJECT = AD_VALUE.object;

        ITEMS[i] = .{
            .id = try allocator.dupe(u8, stringValue(AD_OBJECT, "id") orelse ""),
            .name = try allocator.dupe(u8, stringValue(AD_OBJECT, "name") orelse ""),
            .ad_type = try allocator.dupe(u8, stringValue(AD_OBJECT, "type") orelse ""),
            .ad_group_id = try allocator.dupe(
                u8,
                resourceId(stringValue(AD_GROUP_AD, "adGroup") orelse ""),
            ),
            .status = try allocator.dupe(u8, stringValue(AD_GROUP_AD, "status") orelse ""),
        };
    }

    return ITEMS;
}

fn stringValue(object: STD.json.ObjectMap, key: []const u8) ?[]const u8 {
    const VALUE = object.get(key) orelse return null;

    return switch (VALUE) {
        .string => |text| text,
        else => null,
    };
}

pub fn freeAccount(allocator: STD.mem.Allocator, account: ACCOUNT) void {
    allocator.free(account.id);
    allocator.free(account.name);
}

pub fn freeCampaigns(allocator: STD.mem.Allocator, campaigns: []CAMPAIGN) void {
    for (campaigns) |campaign| {
        allocator.free(campaign.id);
        allocator.free(campaign.name);
        allocator.free(campaign.status);
        allocator.free(campaign.channel_type);
    }

    allocator.free(campaigns);
}

pub fn freeAdGroups(allocator: STD.mem.Allocator, ad_groups: []AD_GROUP) void {
    for (ad_groups) |ad_group| {
        allocator.free(ad_group.id);
        allocator.free(ad_group.name);
        allocator.free(ad_group.status);
        allocator.free(ad_group.campaign_id);
    }

    allocator.free(ad_groups);
}

pub fn freeAds(allocator: STD.mem.Allocator, ads: []AD) void {
    for (ads) |ad| {
        allocator.free(ad.id);
        allocator.free(ad.name);
        allocator.free(ad.ad_type);
        allocator.free(ad.ad_group_id);
        allocator.free(ad.status);
    }

    allocator.free(ads);
}
