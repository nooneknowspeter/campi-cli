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
