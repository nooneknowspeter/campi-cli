const ENV_MODULE = @import("../../cli/env.zig");

pub const DEFAULT_GRAPH_API_URL = "https://graph.facebook.com";

pub const ENV = [_]ENV_MODULE.Field{
    .{ .key = "token", .env_var = "CAMPI_META_TOKEN" },
    .{ .key = "ad_account_id", .env_var = "CAMPI_META_AD_ACCOUNT" },
    .{ .key = "page_id", .env_var = "CAMPI_META_PAGE_ID" },
    .{ .key = "graph_api_url", .env_var = "CAMPI_META_GRAPH_API_URL", .default = DEFAULT_GRAPH_API_URL },
};
