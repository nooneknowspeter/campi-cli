pub const AD = struct {
    name: [][]const u8,
    budget: usize,
    domestic_targets: struct {},
};

pub const AD_SET = struct {
    name: [][]const u8,
    ads: []AD,
};

pub const CAMPAIGN = struct {
    name: [][]const u8,
    ads: []AD,
    ad_sets: []AD_SET,
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
