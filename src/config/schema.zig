const FILE_LOCATION_TYPE = enum {
    local,
    cloud,
};

const MANIFEST_FILES = union(enum) {
    globs: []const []const u8,
    manifest_files: ?[]const []const u8,
};

pub const META_CONFIG = struct {
    token_env: ?[]const u8 = null,
    ad_account_id_env: ?[]const u8 = null,
    page_id_env: ?[]const u8 = null,
    instagram_user_id_env: ?[]const u8 = null,
    graph_api_url_env: ?[]const u8 = null,
};

pub const TIKTOK_CONFIG = struct {
    token_env: ?[]const u8 = null,
};

pub const CONFIG = struct {
    campi_version: []const u8,
    config_version: []const u8,
    project_name: []const u8,
    state_file_location_type: FILE_LOCATION_TYPE,
    state_file_uri: []const u8,

    platform_configs: struct {
        meta: ?META_CONFIG,
        x: ?struct {},
        tiktok: ?TIKTOK_CONFIG,
        google: ?struct {},
        reddit: ?struct {},
        linkedin: ?struct {},
    },

    manifest_files: MANIFEST_FILES,
};
