pub const CAMPAIGN = struct {
    campaign: []const u8,
    external_id: ?[]const u8,
    input_manifest: ?[]const u8,
};

pub const STATE = struct {
    state_version: []const u8,
    applied_at: ?[]const u8,
    manifest_files: []const []const u8,
    platforms: struct {
        meta: ?[]CAMPAIGN,
        x: ?[]CAMPAIGN,
        tiktok: ?[]CAMPAIGN,
        google: ?[]CAMPAIGN,
        reddit: ?[]CAMPAIGN,
        linkedin: ?[]CAMPAIGN,
    },
};
