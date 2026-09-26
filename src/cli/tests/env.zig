const STD = @import("std");

const ENV = @import("../env.zig");

const TEST_FIELDS = [_]ENV.Field{
    .{ .key = "token", .env_var = "CAMPI_META_ACCESS_TOKEN" },
    .{ .key = "ad_account_id", .env_var = "CAMPI_META_AD_ACCOUNT" },
    .{ .key = "page_id", .env_var = "CAMPI_META_PAGE_ID", .required = false },
    .{ .key = "instagram_actor_id", .env_var = "CAMPI_META_INSTAGRAM_ACTOR_ID", .required = false },
    .{ .key = "graph_api_url", .env_var = "CAMPI_META_GRAPH_API_URL", .default = "https://graph.facebook.com" },
};

const TOKEN_ONLY: STD.process.Environ = .{
    .block = .{
        .slice = &[1:null]?[*:0]const u8{
            @as(?[*:0]const u8, "CAMPI_META_ACCESS_TOKEN=tok123"),
        },
    },
};

const TOKEN_AND_ACCOUNT: STD.process.Environ = .{ .block = .{ .slice = &[2:null]?[*:0]const u8{
    @as(?[*:0]const u8, "CAMPI_META_ACCESS_TOKEN=tok123"),
    @as(?[*:0]const u8, "CAMPI_META_AD_ACCOUNT=act_456"),
} } };

test "findMissingEnvVar returns the first absent required field" {
    const MISSING = ENV.findMissingEnvVar(TOKEN_ONLY, &TEST_FIELDS);
    try STD.testing.expect(MISSING != null);
    try STD.testing.expectEqualStrings("ad_account_id", MISSING.?.key);
}

test "findMissingEnvVar reports nothing when all required fields are present" {
    try STD.testing.expectEqual(@as(?ENV.Field, null), ENV.findMissingEnvVar(TOKEN_AND_ACCOUNT, &TEST_FIELDS));
}

test "findMissingEnvVar skips absent non-required fields" {
    try STD.testing.expectEqual(@as(?ENV.Field, null), ENV.findMissingEnvVar(TOKEN_AND_ACCOUNT, &TEST_FIELDS));
}

test "findEnvVarValue returns the value for a present key" {
    try STD.testing.expectEqualStrings("tok123", ENV.findEnvVarValue(TOKEN_AND_ACCOUNT, &TEST_FIELDS, "token").?);
}

test "findEnvVarValue falls back to the declared default" {
    try STD.testing.expectEqualStrings(
        "https://graph.facebook.com",
        ENV.findEnvVarValue(TOKEN_ONLY, &TEST_FIELDS, "graph_api_url").?,
    );
}

test "findEnvVarValue returns null for an absent optional field" {
    try STD.testing.expectEqual(
        @as(?[]const u8, null),
        ENV.findEnvVarValue(TOKEN_AND_ACCOUNT, &TEST_FIELDS, "page_id"),
    );
}
