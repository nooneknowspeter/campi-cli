const ENV_MODULE = @import("../../cli/env.zig");

pub const GRAPH_API_VERSION = "v26.0";

pub const DEFAULT_GRAPH_API_URL = "https://graph.facebook.com/" ++ GRAPH_API_VERSION;

pub const ENV = [_]ENV_MODULE.Field{
    .{ .key = "token", .env_var = "CAMPI_META_ACCESS_TOKEN" },
    .{ .key = "ad_account_id", .env_var = "CAMPI_META_AD_ACCOUNT" },
    .{ .key = "page_id", .env_var = "CAMPI_META_PAGE_ID", .required = false },
    .{ .key = "instagram_actor_id", .env_var = "CAMPI_META_INSTAGRAM_ACTOR_ID", .required = false },
    .{ .key = "graph_api_url", .env_var = "CAMPI_META_GRAPH_API_URL", .default = DEFAULT_GRAPH_API_URL },
};
