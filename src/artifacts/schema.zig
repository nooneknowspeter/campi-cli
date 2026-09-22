pub const SOURCE_KIND = union(enum) {
    remote,
    local,
};

pub const DownloadedArtifact = struct {
    source: []const u8,
    content_type: []const u8,
    bytes: []const u8,
};

pub const ARTIFACT_RESULT = struct {
    artifacts: []DownloadedArtifact,
    failed: []const []const u8,
    invalid: bool,
};
