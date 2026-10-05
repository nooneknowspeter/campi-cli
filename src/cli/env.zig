const STD = @import("std");

pub const Field = struct {
    key: []const u8,
    env_var: []const u8,
    required: bool = true,
    default: ?[]const u8 = null,
};

pub const Override = struct {
    key: []const u8,
    env_var: []const u8,
};

pub fn envVarFor(
    comptime fields: []const Field,
    comptime key: []const u8,
    overrides: ?[]const Override,
) []const u8 {
    if (overrides) |OVERRIDES|
        for (OVERRIDES) |override|
            if (STD.mem.eql(u8, override.key, key))
                return override.env_var;

    inline for (fields) |field| {
        if (comptime STD.mem.eql(u8, field.key, key))
            return field.env_var;
    }

    @compileError("unknown env field: " ++ key);
}

/// Resolve the environment variable name for a runtime-known key, applying
/// overrides first and falling back to the env table.
pub fn effectiveEnvVar(
    comptime fields: []const Field,
    key: []const u8,
    overrides: ?[]const Override,
) []const u8 {
    if (overrides) |OVERRIDES|
        for (OVERRIDES) |override|
            if (STD.mem.eql(u8, override.key, key))
                return override.env_var;

    for (fields) |field| {
        if (STD.mem.eql(u8, field.key, key))
            return field.env_var;
    }

    return key;
}

/// Build override entries from a platform config struct: every optional
/// []const u8 field must end in `_env`; its env key is the field name with
/// the `_env` suffix removed and must match an env table key exactly.
pub fn overridesFor(allocator: STD.mem.Allocator, config: anytype) ![]const Override {
    var list: STD.ArrayList(Override) = .empty;
    errdefer list.deinit(allocator);

    inline for (STD.meta.fields(@TypeOf(config))) |field| {
        comptime {
            if (field.type != ?[]const u8)
                @compileError("platform config fields must be optional strings");
            if (!STD.mem.endsWith(u8, field.name, "_env"))
                @compileError("platform config field '" ++ field.name ++ "' must end with _env");
        }
        const VALUE = @field(config, field.name);
        if (VALUE) |ENV_VAR_NAME| {
            const KEY = field.name[0 .. field.name.len - "_env".len];
            try list.append(allocator, .{ .key = KEY, .env_var = ENV_VAR_NAME });
        }
    }

    return list.toOwnedSlice(allocator);
}

/// Unwraps the nullable platform config; a null config stays null.
pub fn overridesFromConfig(
    allocator: STD.mem.Allocator,
    platform_config: anytype,
) !?[]const Override {
    if (platform_config) |PLATFORM_CONFIG|
        return try overridesFor(allocator, PLATFORM_CONFIG);

    return null;
}

fn isEnvVarValueBlank(value: []const u8) bool {
    return STD.mem.trim(u8, value, " \t\r").len == 0;
}

pub fn findMissingEnvVar(
    environ: STD.process.Environ,
    comptime fields: []const Field,
    overrides: ?[]const Override,
) ?Field {
    inline for (fields) |field| {
        if (!field.required) continue;
        if (field.default != null) continue;

        const VALUE = STD.process.Environ.getPosix(environ, envVarFor(fields, field.key, overrides));

        if (VALUE == null or isEnvVarValueBlank(VALUE.?)) return field;
    }

    return null;
}

pub fn findEnvVarValue(
    environ: STD.process.Environ,
    comptime fields: []const Field,
    comptime key: []const u8,
    overrides: ?[]const Override,
) ?[]const u8 {
    if (STD.process.Environ.getPosix(environ, envVarFor(fields, key, overrides))) |value| {
        if (!isEnvVarValueBlank(value)) return value;
    }

    inline for (fields) |field| {
        if (comptime STD.mem.eql(u8, field.key, key))
            return field.default;
    }

    @compileError("unknown env field: " ++ key);
}
