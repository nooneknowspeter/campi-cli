const STD = @import("std");

pub const CAMPAIGN = struct {
    id: []const u8,
    name: []const u8,
    status: []const u8,
    objective: []const u8,
};

pub const AD_SET = struct {
    id: []const u8,
    name: []const u8,
    campaign_id: []const u8,
    status: []const u8,
};

pub const AD = struct {
    id: []const u8,
    name: []const u8,
    ad_set_id: []const u8,
    status: []const u8,
};

pub const INSIGHTS = struct {
    reach: u64 = 0,
    impressions: u64 = 0,
    clicks: u64 = 0,
    spend_cents: u64 = 0,
};

pub const INSTAGRAM_ACCOUNT = struct {
    id: []const u8,
    ig_id: ?[]const u8 = null,
    username: ?[]const u8 = null,
    name: ?[]const u8 = null,
};

pub const PAGE = struct {
    id: []const u8,
    name: []const u8,
    category: ?[]const u8 = null,
};

pub fn decodeInstagramAccounts(
    allocator: STD.mem.Allocator,
    document: []const u8,
) !?[]INSTAGRAM_ACCOUNT {
    const PARSED = try STD.json.parseFromSlice(
        STD.json.Value,
        allocator,
        document,
        .{},
    );
    defer PARSED.deinit();

    const ROOT = PARSED.value;
    const DATA = ROOT.object.get("data") orelse return null;

    const ACCOUNTS = try allocator.alloc(INSTAGRAM_ACCOUNT, DATA.array.items.len);

    for (DATA.array.items, 0..) |item, i| {
        const OBJECT = item.object;
        const ID = OBJECT.get("id") orelse return error.MetaRequestFailed;

        ACCOUNTS[i] = .{
            .id = try allocator.dupe(u8, ID.string),
            .ig_id = try optionalString(allocator, OBJECT, "ig_id"),
            .username = try optionalString(allocator, OBJECT, "username"),
            .name = try optionalString(allocator, OBJECT, "name"),
        };
    }

    return ACCOUNTS;
}

fn optionalString(
    allocator: STD.mem.Allocator,
    object: STD.json.ObjectMap,
    key: []const u8,
) !?[]const u8 {
    const VALUE = object.get(key) orelse return null;

    return switch (VALUE) {
        .string => |text| try allocator.dupe(u8, text),
        else => null,
    };
}

fn parseIdNumber(value: STD.json.Value) ?STD.json.Value {
    return switch (value) {
        .integer => |integer| STD.json.Value{ .integer = integer },
        .float => |float| STD.json.Value{ .integer = @intFromFloat(float) },
        .string => blk: {
            const NUMBER = STD.fmt.parseInt(u64, value.string, 10) catch
                break :blk null;

            break :blk STD.json.Value{ .integer = NUMBER };
        },
        else => null,
    };
}

fn numberValue(value: ?STD.json.Value) ?u64 {
    const VALUE = value orelse return null;

    const NUMBER = parseIdNumber(VALUE) orelse return null;

    return switch (NUMBER) {
        .integer => |integer| @intCast(integer),
        else => null,
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

    const ROOT = PARSED.value;
    const DATA = ROOT.object.get("data") orelse return null;

    const ITEMS = try allocator.alloc(CAMPAIGN, DATA.array.items.len);

    for (DATA.array.items, 0..) |item, i| {
        const OBJECT = item.object;

        ITEMS[i] = .{
            .id = try allocator.dupe(u8, OBJECT.get("id").?.string),
            .name = try allocator.dupe(u8, OBJECT.get("name").?.string),
            .status = try allocator.dupe(u8, OBJECT.get("status").?.string),
            .objective = try allocator.dupe(
                u8,
                OBJECT.get("objective").?.string,
            ),
        };
    }

    return ITEMS;
}

pub fn decodeAdSets(
    allocator: STD.mem.Allocator,
    document: []const u8,
) !?[]AD_SET {
    const PARSED = try STD.json.parseFromSlice(
        STD.json.Value,
        allocator,
        document,
        .{},
    );
    defer PARSED.deinit();

    const ROOT = PARSED.value;
    const DATA = ROOT.object.get("data") orelse return null;

    const ITEMS = try allocator.alloc(AD_SET, DATA.array.items.len);

    for (DATA.array.items, 0..) |item, i| {
        const OBJECT = item.object;

        ITEMS[i] = .{
            .id = try allocator.dupe(u8, OBJECT.get("id").?.string),
            .name = try allocator.dupe(u8, OBJECT.get("name").?.string),
            .campaign_id = try allocator.dupe(
                u8,
                OBJECT.get("campaign_id").?.string,
            ),
            .status = try allocator.dupe(u8, OBJECT.get("status").?.string),
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

    const ROOT = PARSED.value;
    const DATA = ROOT.object.get("data") orelse return null;

    const ITEMS = try allocator.alloc(AD, DATA.array.items.len);

    for (DATA.array.items, 0..) |item, i| {
        const OBJECT = item.object;

        ITEMS[i] = .{
            .id = try allocator.dupe(u8, OBJECT.get("id").?.string),
            .name = try allocator.dupe(u8, OBJECT.get("name").?.string),
            .ad_set_id = try allocator.dupe(
                u8,
                OBJECT.get("adset_id").?.string,
            ),
            .status = try allocator.dupe(u8, OBJECT.get("status").?.string),
        };
    }

    return ITEMS;
}

pub fn decodePages(
    allocator: STD.mem.Allocator,
    document: []const u8,
) !?[]PAGE {
    const PARSED = try STD.json.parseFromSlice(
        STD.json.Value,
        allocator,
        document,
        .{},
    );
    defer PARSED.deinit();

    const ROOT = PARSED.value;
    const DATA = ROOT.object.get("data") orelse return null;

    const ITEMS = try allocator.alloc(PAGE, DATA.array.items.len);

    for (DATA.array.items, 0..) |item, i| {
        const OBJECT = item.object;

        ITEMS[i] = .{
            .id = try allocator.dupe(u8, OBJECT.get("id").?.string),
            .name = try allocator.dupe(u8, OBJECT.get("name").?.string),
            .category = try optionalString(allocator, OBJECT, "category"),
        };
    }

    return ITEMS;
}

pub fn freeCampaigns(allocator: STD.mem.Allocator, campaigns: []CAMPAIGN) void {
    for (campaigns) |campaign| {
        allocator.free(campaign.id);
        allocator.free(campaign.name);
        allocator.free(campaign.status);
        allocator.free(campaign.objective);
    }

    allocator.free(campaigns);
}

pub fn freeAdSets(allocator: STD.mem.Allocator, ad_sets: []AD_SET) void {
    for (ad_sets) |ad_set| {
        allocator.free(ad_set.id);
        allocator.free(ad_set.name);
        allocator.free(ad_set.campaign_id);
        allocator.free(ad_set.status);
    }

    allocator.free(ad_sets);
}

pub fn freeAds(allocator: STD.mem.Allocator, ads: []AD) void {
    for (ads) |ad| {
        allocator.free(ad.id);
        allocator.free(ad.name);
        allocator.free(ad.ad_set_id);
        allocator.free(ad.status);
    }

    allocator.free(ads);
}

pub fn freePages(allocator: STD.mem.Allocator, pages: []PAGE) void {
    for (pages) |page| {
        allocator.free(page.id);
        allocator.free(page.name);
        if (page.category) |category| allocator.free(category);
    }

    allocator.free(pages);
}

pub fn freeInstagramAccounts(
    allocator: STD.mem.Allocator,
    accounts: []INSTAGRAM_ACCOUNT,
) void {
    for (accounts) |account| {
        allocator.free(account.id);
        if (account.ig_id) |ig_id| allocator.free(ig_id);
        if (account.username) |username| allocator.free(username);
        if (account.name) |name| allocator.free(name);
    }

    allocator.free(accounts);
}
