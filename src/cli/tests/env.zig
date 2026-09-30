const STD = @import("std");

const ENV = @import("../env.zig");

const TEST_FIELDS = [_]ENV.Field{
    .{ .key = "token", .env_var = "CAMPI_META_ACCESS_TOKEN" },
    .{ .key = "ad_account_id", .env_var = "CAMPI_META_AD_ACCOUNT" },
    .{ .key = "page_id", .env_var = "CAMPI_META_PAGE_ID", .required = false },
    .{ .key = "instagram_actor_id", .env_var = "CAMPI_META_INSTAGRAM_ACTOR_ID", .required = false },
    .{ .key = "graph_api_url", .env_var = "CAMPI_META_GRAPH_API_URL", .default = "https://graph.facebook.com/v26.0" },
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
    const MISSING = ENV.findMissingEnvVar(TOKEN_ONLY, &TEST_FIELDS, null);
    try STD.testing.expect(MISSING != null);
    try STD.testing.expectEqualStrings("ad_account_id", MISSING.?.key);
}

test "findMissingEnvVar reports nothing when all required fields are present" {
    try STD.testing.expectEqual(@as(?ENV.Field, null), ENV.findMissingEnvVar(TOKEN_AND_ACCOUNT, &TEST_FIELDS, null));
}

test "findMissingEnvVar skips absent non-required fields" {
    try STD.testing.expectEqual(@as(?ENV.Field, null), ENV.findMissingEnvVar(TOKEN_AND_ACCOUNT, &TEST_FIELDS, null));
}

test "findEnvVarValue returns the value for a present key" {
    try STD.testing.expectEqualStrings("tok123", ENV.findEnvVarValue(TOKEN_AND_ACCOUNT, &TEST_FIELDS, "token", null).?);
}

test "findEnvVarValue falls back to the declared default" {
    try STD.testing.expectEqualStrings(
        "https://graph.facebook.com/v26.0",
        ENV.findEnvVarValue(TOKEN_ONLY, &TEST_FIELDS, "graph_api_url", null).?,
    );
}

test "findEnvVarValue returns null for an absent optional field" {
    try STD.testing.expectEqual(
        @as(?[]const u8, null),
        ENV.findEnvVarValue(TOKEN_AND_ACCOUNT, &TEST_FIELDS, "page_id", null),
    );
}

const OVERRIDES = [_]ENV.Override{
    .{ .key = "token", .env_var = "MY_META_TOKEN" },
};

const MY_TOKEN_ONLY: STD.process.Environ = .{
    .block = .{ .slice = &[1:null]?[*:0]const u8{
        @as(?[*:0]const u8, "MY_META_TOKEN=tok123"),
    } },
};

test "overrides replace the env var name" {
    try STD.testing.expectEqualStrings(
        "tok123",
        ENV.findEnvVarValue(MY_TOKEN_ONLY, &TEST_FIELDS, "token", &OVERRIDES).?,
    );
}

test "overrides report missing despite the stock name being set" {
    const MISSING = ENV.findMissingEnvVar(TOKEN_AND_ACCOUNT, &TEST_FIELDS, &OVERRIDES);
    try STD.testing.expect(MISSING != null);
    try STD.testing.expectEqualStrings("token", MISSING.?.key);
}

test "overrides are ignored when null" {
    try STD.testing.expectEqualStrings(
        "tok123",
        ENV.findEnvVarValue(TOKEN_AND_ACCOUNT, &TEST_FIELDS, "token", null).?,
    );
}

const TEST_CONFIG = struct {
    token_env: ?[]const u8 = "MY_META_TOKEN",
    ad_account_id_env: ?[]const u8 = null,
};

test "overrides builds entries from a config struct" {
    var arena = STD.heap.ArenaAllocator.init(STD.testing.allocator);
    defer arena.deinit();

    const ENTRIES = try ENV.overridesFor(arena.allocator(), TEST_CONFIG{});
    try STD.testing.expectEqual(@as(usize, 1), ENTRIES.len);
    try STD.testing.expectEqualStrings("token", ENTRIES[0].key);
    try STD.testing.expectEqualStrings("MY_META_TOKEN", ENTRIES[0].env_var);
}

test "overridesFromConfig passes null config through" {
    var arena = STD.heap.ArenaAllocator.init(STD.testing.allocator);
    defer arena.deinit();

    const NULL_CONFIG: ?TEST_CONFIG = null;
    try STD.testing.expectEqual(
        @as(?[]const ENV.Override, null),
        try ENV.overridesFromConfig(arena.allocator(), NULL_CONFIG),
    );
}
