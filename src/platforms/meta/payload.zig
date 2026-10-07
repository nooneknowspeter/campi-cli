const STD = @import("std");

const MANIFEST = @import("../../manifest/schema.zig");

pub fn outcomeFor(objective: MANIFEST.OBJECTIVE) []const u8 {
    return switch (objective) {
        .AWARENESS => "OUTCOME_AWARENESS",
        .TRAFFIC => "OUTCOME_TRAFFIC",
        .LEADS => "OUTCOME_LEADS",
        .CONVERSIONS => "OUTCOME_SALES",
        .APP_INSTALLS => "OUTCOME_APP_INSTALLS",
    };
}

pub fn statusFor(status: ?MANIFEST.STATUS) []const u8 {
    return switch (status orelse .ACTIVE) {
        .ACTIVE => "ACTIVE",
        .PAUSED => "PAUSED",
        .ARCHIVED => "ACTIVE",
    };
}

pub fn optimizationGoalFor(goal: ?MANIFEST.OPTIMIZATION_GOAL) []const u8 {
    return switch (goal orelse .CLICKS) {
        .IMPRESSIONS => "IMPRESSIONS",
        .CLICKS => "LINK_CLICKS",
        .CONVERSIONS => "CONVERSIONS",
        .REACH => "REACH",
    };
}

pub fn callToActionFor(cta: MANIFEST.CALL_TO_ACTION) []const u8 {
    return switch (cta) {
        .LEARN_MORE => "LEARN_MORE",
        .SIGN_UP => "SIGN_UP",
        .SHOP_NOW => "SHOP_NOW",
        .DOWNLOAD => "DOWNLOAD",
        .CONTACT_US => "CONTACT_US",
        .BOOK_NOW => "BOOK_NOW",
        .SUBSCRIBE => "SUBSCRIBE",
        .WATCH_MORE => "WATCH_MORE",
    };
}

pub fn specialAdCategoryFor(category: MANIFEST.SPECIAL_AD_CATEGORY) []const u8 {
    return switch (category) {
        .NONE => "NONE",
        .EMPLOYMENT => "EMPLOYMENT",
        .HOUSING => "HOUSING",
        .CREDIT => "CREDIT",
        .ISSUES_ELECTIONS_POLITICS => "ISSUES_ELECTIONS_POLITICS",
        .ONLINE_GAMBLING_AND_GAMING => "ONLINE_GAMBLING_AND_GAMING",
        .FINANCIAL_PRODUCTS_SERVICES => "FINANCIAL_PRODUCTS_SERVICES",
    };
}

pub fn dailyBudget(allocator: STD.mem.Allocator, amount_in_cents: usize) ![]const u8 {
    return STD.fmt.allocPrint(allocator, "{d}", .{amount_in_cents});
}

fn campaignObject(allocator: STD.mem.Allocator, campaign: MANIFEST.CAMPAIGN) !STD.json.Value {
    var json_payload = STD.json.Value{ .object = .empty };

    try json_payload.object.put(allocator, "name", .{ .string = campaign.name });
    try json_payload.object.put(allocator, "objective", .{ .string = outcomeFor(campaign.objective) });
    try json_payload.object.put(allocator, "status", .{ .string = statusFor(campaign.status) });

    var special_ad_categories = STD.json.Value{ .array = STD.json.Array.init(allocator) };
    for (campaign.special_ad_categories) |category|
        try special_ad_categories.array.append(.{ .string = specialAdCategoryFor(category) });
    try json_payload.object.put(allocator, "special_ad_categories", special_ad_categories);

    if (campaign.budget) |budget|
        try json_payload.object.put(allocator, "daily_budget", .{
            .string = try dailyBudget(allocator, budget.amount_in_cents),
        })
    else
        try json_payload.object.put(allocator, "is_adset_budget_sharing_enabled", .{ .bool = false });

    return json_payload;
}

pub fn campaignPayload(allocator: STD.mem.Allocator, campaign: MANIFEST.CAMPAIGN) ![]const u8 {
    return STD.json.Stringify.valueAlloc(allocator, try campaignObject(allocator, campaign), .{});
}

pub fn adSetPayload(
    allocator: STD.mem.Allocator,
    ad_group: MANIFEST.AD_GROUP,
    campaign_id: []const u8,
) ![]const u8 {
    var json_payload = STD.json.Value{ .object = .empty };

    const GROUP_NAME = if (ad_group.name.len > 0) ad_group.name[0] else "";

    try json_payload.object.put(allocator, "name", .{ .string = GROUP_NAME });
    try json_payload.object.put(allocator, "campaign_id", .{ .string = campaign_id });
    try json_payload.object.put(allocator, "billing_event", .{ .string = "IMPRESSIONS" });
    try json_payload.object.put(allocator, "optimization_goal", .{
        .string = optimizationGoalFor(ad_group.optimization_goal),
    });
    try json_payload.object.put(allocator, "status", .{ .string = statusFor(ad_group.status) });

    if (ad_group.budget) |budget|
        try json_payload.object.put(allocator, "daily_budget", .{
            .string = try dailyBudget(allocator, budget.amount_in_cents),
        });

    try json_payload.object.put(allocator, "targeting", try targetingObject(allocator, ad_group.target));

    return STD.json.Stringify.valueAlloc(allocator, json_payload, .{});
}

pub const CREATIVE_DESTINATION = struct {
    page_id: ?[]const u8 = null,
    instagram_user_id: ?[]const u8 = null,
};

pub fn creativePayload(
    allocator: STD.mem.Allocator,
    destination: CREATIVE_DESTINATION,
    ad: MANIFEST.AD,
    image_hash: []const u8,
) ![]const u8 {
    var link_data = STD.json.Value{ .object = .empty };

    try link_data.object.put(allocator, "link", .{ .string = ad.CREATIVE.destination_url });
    try link_data.object.put(allocator, "name", .{ .string = ad.CREATIVE.headline });
    try link_data.object.put(allocator, "message", .{ .string = ad.CREATIVE.body_text });
    try link_data.object.put(allocator, "image_hash", .{ .string = image_hash });

    var call_to_action = STD.json.Value{ .object = .empty };
    try call_to_action.object.put(allocator, "type", .{
        .string = callToActionFor(ad.CREATIVE.call_to_action),
    });
    try link_data.object.put(allocator, "call_to_action", call_to_action);

    var spec = STD.json.Value{ .object = .empty };
    try spec.object.put(allocator, "type", .{ .string = "link" });
    if (destination.page_id) |page_id|
        try spec.object.put(allocator, "page_id", .{ .string = page_id });
    if (destination.instagram_user_id) |instagram_user_id|
        try spec.object.put(allocator, "instagram_user_id", .{ .string = instagram_user_id });
    try spec.object.put(allocator, "link_data", link_data);

    var json_payload = STD.json.Value{ .object = .empty };
    try json_payload.object.put(allocator, "name", .{ .string = ad.name });
    try json_payload.object.put(allocator, "object_story_spec", spec);

    return STD.json.Stringify.valueAlloc(allocator, json_payload, .{});
}

pub fn adPayload(
    allocator: STD.mem.Allocator,
    ad: MANIFEST.AD,
    ad_set_id: []const u8,
    creative_id: []const u8,
) ![]const u8 {
    var creative = STD.json.Value{ .object = .empty };
    try creative.object.put(allocator, "creative_id", .{ .string = creative_id });

    var json_payload = STD.json.Value{ .object = .empty };
    try json_payload.object.put(allocator, "name", .{ .string = ad.name });
    try json_payload.object.put(allocator, "adset_id", .{ .string = ad_set_id });
    try json_payload.object.put(allocator, "status", .{ .string = statusFor(ad.status) });
    try json_payload.object.put(allocator, "creative", creative);

    return STD.json.Stringify.valueAlloc(allocator, json_payload, .{});
}

fn targetingObject(allocator: STD.mem.Allocator, target: ?MANIFEST.TARGET) !STD.json.Value {
    var json_payload = STD.json.Value{ .object = .empty };

    const VALUE = target orelse return json_payload;

    if (VALUE.locations) |locations| {
        var geo_locations = STD.json.Value{ .object = .empty };

        var countries = STD.json.Value{ .array = STD.json.Array.init(allocator) };
        for (locations.include) |location| {
            var entry = STD.json.Value{ .object = .empty };
            try entry.object.put(allocator, "country", .{ .string = location.country });
            try countries.array.append(entry);
        }
        try geo_locations.object.put(allocator, "countries", countries);

        try json_payload.object.put(allocator, "geo_locations", geo_locations);
    }

    if (VALUE.age_min) |age_min|
        try json_payload.object.put(allocator, "age_min", .{ .integer = age_min });

    if (VALUE.age_max) |age_max|
        try json_payload.object.put(allocator, "age_max", .{ .integer = age_max });

    if (VALUE.genders) |genders| {
        var codes = STD.json.Value{ .array = STD.json.Array.init(allocator) };
        for (genders) |gender| {
            const CODE: i64 = switch (gender) {
                .MALE => 1,
                .FEMALE => 2,
                .OTHER => 2,
            };
            try codes.array.append(.{ .integer = CODE });
        }
        try json_payload.object.put(allocator, "genders", codes);
    }

    return json_payload;
}
