const STD = @import("std");

pub const SCHEMA = @import("schema.zig");

pub const ACCESS_TOKEN_ENV = "CAMPI_TIKTOK_TOKEN";

pub fn hasAccessToken(environ: STD.process.Environ) bool {
    return STD.process.Environ.containsUnemptyConstant(environ, ACCESS_TOKEN_ENV);
}