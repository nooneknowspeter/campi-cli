const FILE_LOCATION_TYPE = enum {
    local,
    cloud,
};

const MANIFEST_FILES = union(enum) {
    regex: []const u8,
    manifest_files: ?[]const []const u8,
};

pub const CONFIG = struct {
    campi_version: []const u8,
    config_version: []const u8,
    project_name: []const u8,
    state_file_location_type: FILE_LOCATION_TYPE,
    state_file_uri: []const u8,

    platform_configs: struct {
        meta: ?struct {},
        x: ?struct {},
        tiktok: ?struct {},
        google: ?struct {},
        reddit: ?struct {},
        linkedin: ?struct {},
    },

    manifest_files: MANIFEST_FILES,
};
