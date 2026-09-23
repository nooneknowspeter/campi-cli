const STD = @import("std");

pub const Field = struct {
    key: []const u8,
    env_var: []const u8,
    required: bool = true,
    default: ?[]const u8 = null,
};

pub fn findMissingEnvVar(
    environ: STD.process.Environ,
    comptime fields: []const Field,
) ?Field {
    inline for (fields) |field| {
        if (!field.required) continue;
        if (field.default != null) continue;
        if (STD.process.Environ.getPosix(environ, field.env_var) == null)
            return field;
    }

    return null;
}

pub fn findEnvVarValue(
    environ: STD.process.Environ,
    comptime fields: []const Field,
    comptime key: []const u8,
) ?[]const u8 {
    inline for (fields) |field| {
        if (comptime STD.mem.eql(u8, field.key, key)) {
            if (STD.process.Environ.getPosix(environ, field.env_var)) |value|
                return value;

            return field.default;
        }
    }

    @compileError("unknown env field: " ++ key);
}

const TEST_FIELDS = [_]Field{
    .{ .key = "token", .env_var = "CAMPI_META_TOKEN" },
    .{ .key = "ad_account_id", .env_var = "CAMPI_META_AD_ACCOUNT" },
    .{ .key = "page_id", .env_var = "CAMPI_META_PAGE_ID", .required = false },
    .{ .key = "graph_api_url", .env_var = "CAMPI_META_GRAPH_API_URL", .default = "https://graph.facebook.com" },
};

const TOKEN_ONLY: STD.process.Environ = .{ .block = .{ .slice = &[1:null]?[*:0]const u8{
    @as(?[*:0]const u8, "CAMPI_META_TOKEN=tok123"),
} } };

const TOKEN_AND_ACCOUNT: STD.process.Environ = .{ .block = .{ .slice = &[2:null]?[*:0]const u8{
    @as(?[*:0]const u8, "CAMPI_META_TOKEN=tok123"),
    @as(?[*:0]const u8, "CAMPI_META_AD_ACCOUNT=act_456"),
} } };

test "findMissingEnvVar returns the first absent required field" {
    const MISSING = findMissingEnvVar(TOKEN_ONLY, &TEST_FIELDS);
    try STD.testing.expect(MISSING != null);
    try STD.testing.expectEqualStrings("ad_account_id", MISSING.?.key);
}

test "findMissingEnvVar reports nothing when all required fields are present" {
    try STD.testing.expectEqual(@as(?Field, null), findMissingEnvVar(TOKEN_AND_ACCOUNT, &TEST_FIELDS));
}

test "findMissingEnvVar skips absent non-required fields" {
    try STD.testing.expectEqual(@as(?Field, null), findMissingEnvVar(TOKEN_AND_ACCOUNT, &TEST_FIELDS));
}

test "findEnvVarValue returns the value for a present key" {
    try STD.testing.expectEqualStrings("tok123", findEnvVarValue(TOKEN_AND_ACCOUNT, &TEST_FIELDS, "token").?);
}

test "findEnvVarValue falls back to the declared default" {
    try STD.testing.expectEqualStrings(
        "https://graph.facebook.com",
        findEnvVarValue(TOKEN_ONLY, &TEST_FIELDS, "graph_api_url").?,
    );
}
