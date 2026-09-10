pub const OPERATION_TYPE = enum {
    create,
    update,
    archive,
};

pub const OPERATION = struct {
    platform: []const u8,
    campaign: []const u8,
    operation_type: OPERATION_TYPE,
    external_id: ?[]const u8,
    input_manifest: ?[]const u8,
    manifest_hash: []const u8,
};

pub const PLAN = struct {
    operations: []OPERATION,
};
