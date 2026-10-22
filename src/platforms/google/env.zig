const ENV_MODULE = @import("../../cli/env.zig");

pub const API_VERSION = "v26";

pub const DEFAULT_API_URL = "https://googleads.googleapis.com/" ++ API_VERSION;

pub const DEFAULT_TOKEN_URL = "https://oauth2.googleapis.com/token";

pub const ENV = [_]ENV_MODULE.Field{
    .{ .key = "developer_token", .env_var = "CAMPI_GOOGLE_ADS_DEVELOPER_TOKEN" },
    .{ .key = "client_id", .env_var = "CAMPI_GOOGLE_ADS_CLIENT_ID" },
    .{ .key = "client_secret", .env_var = "CAMPI_GOOGLE_ADS_CLIENT_SECRET" },
    .{ .key = "refresh_token", .env_var = "CAMPI_GOOGLE_ADS_REFRESH_TOKEN" },
    .{ .key = "customer_id", .env_var = "CAMPI_GOOGLE_ADS_CUSTOMER_ID" },
    .{ .key = "login_customer_id", .env_var = "CAMPI_GOOGLE_ADS_LOGIN_CUSTOMER_ID", .required = false },
    .{ .key = "api_url", .env_var = "CAMPI_GOOGLE_ADS_API_URL", .default = DEFAULT_API_URL },
    .{ .key = "token_url", .env_var = "CAMPI_GOOGLE_ADS_TOKEN_URL", .default = DEFAULT_TOKEN_URL },
};
