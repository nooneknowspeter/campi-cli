const STD = @import("std");

const CONFIG = @import("../../config/main.zig");
const CONTEXT = @import("../context.zig");
const FS = @import("../../fs/main.zig");
const MANIFEST = @import("../../manifest/schema.zig");
const PARSER = @import("../parser.zig");

pub const FLAGS = [_]PARSER.FlagDefinition{
    .{
        .long_flag = "write",
        .short_flag = 'w',
        .is_flag_a_boolean = true,
        .description = "Write fixes",
    },
    .{
        .long_flag = "dir",
        .short_flag = 'd',
        .is_flag_a_boolean = false,
        .description = "Run command in the specified working directory",
    },
};

pub fn run(
    allocator: STD.mem.Allocator,
    context: CONTEXT.CommandContext,
    flags: []const PARSER.ResolvedFlagState,
) CONTEXT.ExitCode {
    var path_buffer: [STD.Io.Dir.max_path_bytes]u8 = undefined;

    const DIR_PATH = FS.dirPath(context, flags, &path_buffer) catch {
        context.stderr.print("could not determine the working directory\n", .{}) catch
            return CONTEXT.ExitCode.RUNTIME_FAILURE;

        return CONTEXT.ExitCode.RUNTIME_FAILURE;
    };

    const WORK_DIR = FS.openWorkDir(context, DIR_PATH) catch {
        context.stderr.print("working directory does not exist: {s}\n", .{DIR_PATH}) catch
            return CONTEXT.ExitCode.RUNTIME_FAILURE;

        return CONTEXT.ExitCode.RUNTIME_FAILURE;
    };
    defer WORK_DIR.close(context.io);

    CONFIG.load(allocator, context, WORK_DIR) catch {
        context.stderr.print("could not find config.zon; run campi-cli init\n", .{}) catch
            return CONTEXT.ExitCode.RUNTIME_FAILURE;

        return CONTEXT.ExitCode.RUNTIME_FAILURE;
    };

    var manifest_paths: ?[]const []const u8 = null;

    switch (CONFIG.current_config.?.manifest_files) {
        .regex => |pattern| {
            context.stderr.print("manifest selection by regex is not implemented yet: {s}\n", .{pattern}) catch
                return CONTEXT.ExitCode.RUNTIME_FAILURE;

            return CONTEXT.ExitCode.RUNTIME_FAILURE;
        },
        .manifest_files => |files| manifest_paths = files,
    }

    const MANIFEST_FILES = manifest_paths orelse &.{};

    if (MANIFEST_FILES.len == 0) {
        context.stderr.print("no manifest files configured\n", .{}) catch
            return CONTEXT.ExitCode.RUNTIME_FAILURE;

        return CONTEXT.ExitCode.RUNTIME_FAILURE;
    }

    var invalid = false;

    for (MANIFEST_FILES) |manifest_file| {
        const MANIFEST_SOURCE = WORK_DIR.readFileAllocOptions(
            context.io,
            manifest_file,
            allocator,
            .unlimited,
            .of(u8),
            0,
        ) catch |err| {
            context.stderr.print(
                \\invalid manifest: {s}
                \\
                \\{any}
                \\
            , .{ manifest_file, err }) catch
                return CONTEXT.ExitCode.RUNTIME_FAILURE;

            invalid = true;
            continue;
        };
        defer allocator.free(MANIFEST_SOURCE);

        _ = STD.zon.parse.fromSliceAlloc(
            MANIFEST.MANIFEST,
            allocator,
            MANIFEST_SOURCE,
            null,
            .{},
        ) catch |err| {
            context.stderr.print(
                \\invalid manifest: {s}
                \\
                \\{any}
                \\
            , .{ manifest_file, err }) catch
                return CONTEXT.ExitCode.RUNTIME_FAILURE;

            invalid = true;
            continue;
        };

        context.stdout.print(
            \\valid manifest: {s}
            \\
        , .{manifest_file}) catch
            return CONTEXT.ExitCode.RUNTIME_FAILURE;
    }

    if (invalid) return CONTEXT.ExitCode.RUNTIME_FAILURE;

    context.stdout.print("validated {d} manifest file(s)\n", .{MANIFEST_FILES.len}) catch
        return CONTEXT.ExitCode.RUNTIME_FAILURE;

    return CONTEXT.ExitCode.SUCCESS;
}
