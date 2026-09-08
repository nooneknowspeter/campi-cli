const STD = @import("std");

const BUILD_OPTIONS = @import("build_options");
const CONTEXT = @import("../cli/context.zig");

pub const SCHEMA = @import("schema.zig");

pub var current_config: ?SCHEMA.CONFIG = null;

pub fn defaultConfig(project_name: []const u8) SCHEMA.CONFIG {
    return .{
        .campi_version = BUILD_OPTIONS.version_string,
        .config_version = "0.1.0",
        .project_name = project_name,
        .state_file_location_type = .local,
        .state_file_uri = "state.campi.zon",
        .platform_configs = .{
            .meta = null,
            .x = null,
            .tiktok = null,
            .google = null,
            .reddit = null,
            .linkedin = null,
        },
        .manifest_files = .{ .manifest_files = &.{"example.manifest.campi.zon"} },
    };
}

pub fn load(
    allocator: STD.mem.Allocator,
    context: CONTEXT.CommandContext,
    work_dir: STD.Io.Dir,
) !void {
    const SOURCE = try work_dir.readFileAllocOptions(
        context.io,
        "config.campi.zon",
        allocator,
        .unlimited,
        .of(u8),
        0,
    );

    defer allocator.free(SOURCE);

    current_config = try STD.zon.parse.fromSliceAlloc(SCHEMA.CONFIG, allocator, SOURCE, null, .{});
}
