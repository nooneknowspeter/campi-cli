const ENV_MODULE = @import("../../cli/env.zig");

pub const ENV = [_]ENV_MODULE.Field{
    .{ .key = "token", .env_var = "CAMPI_TIKTOK_TOKEN" },
};
