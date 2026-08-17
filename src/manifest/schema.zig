pub const GENDER = enum {
    MALE,
    FEMALE,
    OTHER,
};

pub const DEVICE_PLATFORM = enum {
    MOBILE,
    DESKTOP,
};

pub const OPTIMIZATION_GOAL = enum {
    IMPRESSIONS,
    CLICKS,
    CONVERSIONS,
    REACH,
};

pub const LOCATION = struct {
    country: []const u8,
    state: ?[]const u8,
    city: ?[]const u8,
    radius_km: ?f32,
};

pub const LOCATION_TARGET = struct {
    include: []LOCATION,
    exclude: ?[]LOCATION,
};

pub const TARGET = struct {
    locations: ?LOCATION_TARGET,
    genders: ?[]GENDER,
    age_min: ?u8,
    age_max: ?u8,
    languages: ?[][]const u8,
    interests: ?[][]const u8,
    devices_platforms: ?[]DEVICE_PLATFORM,
};

pub const BUDGET_TYPE = enum {
    DAILY,
    LIFETIME,
};

pub const BUDGET = struct {
    type: BUDGET_TYPE,
    amount_in_cents: usize,
    currency: []const u8,
};

pub const CREATIVE_MEDIA_TYPE = enum {
    IMAGE,
    VIDEO,
    CAROUSEL,
};

pub const CALL_TO_ACTION = enum {
    LEARN_MORE,
    SIGN_UP,
    SHOP_NOW,
    DOWNLOAD,
    CONTACT_US,
    BOOK_NOW,
    SUBSCRIBE,
    WATCH_MORE,
};

pub const CREATIVE = struct {
    media_type: CREATIVE_MEDIA_TYPE,
    headline: []const u8,
    body_text: []const u8,
    call_to_action: CALL_TO_ACTION,
    media_urls: []const []const u8,
    destination_url: []const u8,
    display_url: ?[]const u8,
};

pub const TRACKING = struct {
    utm_source: ?[]const u8,
    utm_medium: ?[]const u8,
    utm_campaign: ?[]const u8,
};

pub const STATUS = enum {
    ACTIVE,
    PAUSED,
    ARCHIVED,
};

pub const AD = struct {
    name: []const u8,
    status: ?STATUS,
    target: ?TARGET,
    CREATIVE: CREATIVE,
    tracking: ?TRACKING,
};

pub const AD_GROUP = struct {
    name: [][]const u8,
    status: ?STATUS,
    budget: ?BUDGET,
    target: ?TARGET,
    optimization_goal: ?OPTIMIZATION_GOAL,
    bid_amount_in_cents: ?usize,
    ads: []AD,
};

pub const OBJECTIVE = enum {
    AWARENESS,
    TRAFFIC,
    LEADS,
    CONVERSIONS,
    APP_INSTALLS,
};

pub const CAMPAIGN = struct {
    name: []const u8,
    objective: OBJECTIVE,
    status: ?STATUS,
    budget: ?BUDGET,
    ad_groups: []AD_GROUP,
};

pub const MANIFEST = struct {
    campaigns: []CAMPAIGN,

    platforms: struct {
        meta: ?bool,
        x: ?bool,
        tiktok: ?bool,
        google: ?bool,
        reddit: ?bool,
        linkedin: ?bool,
    },
};

