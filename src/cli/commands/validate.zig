const STD = @import("std");

const CONFIG = @import("../../config/main.zig");
const CONTEXT = @import("../context.zig");
const FS = @import("../../fs/main.zig");
const MANIFEST = @import("../../manifest/main.zig");
const PARSER = @import("../parser.zig");

pub const FLAGS = [_]PARSER.FlagDefinition{
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
        context.stderr.print(
            \\{s}
            \\
        , .{CONTEXT.Message.COULD_NOT_DETERMINE_WORKING_DIRECTORY}) catch
            return CONTEXT.ExitCode.RUNTIME_FAILURE;

        return CONTEXT.ExitCode.RUNTIME_FAILURE;
    };

    const WORK_DIR = FS.openWorkDir(context, DIR_PATH) catch {
        context.stderr.print(
            \\{s}{s}
            \\
        , .{ CONTEXT.Message.WORKING_DIRECTORY_DOES_NOT_EXIST, DIR_PATH }) catch
            return CONTEXT.ExitCode.RUNTIME_FAILURE;

        return CONTEXT.ExitCode.RUNTIME_FAILURE;
    };
    defer WORK_DIR.close(context.io);

    CONFIG.load(allocator, context, WORK_DIR) catch {
        context.stderr.print(
            \\{s}
            \\
        , .{CONTEXT.Message.CONFIG_NOT_FOUND}) catch
            return CONTEXT.ExitCode.RUNTIME_FAILURE;

        return CONTEXT.ExitCode.RUNTIME_FAILURE;
    };

    const MANIFEST_FILE_PATHS = MANIFEST.filePaths(context, CONFIG.current_config.?) orelse
        return CONTEXT.ExitCode.RUNTIME_FAILURE;

    const LOADED = MANIFEST.loadAll(allocator, context, WORK_DIR, MANIFEST_FILE_PATHS);

    if (LOADED.invalid) return CONTEXT.ExitCode.RUNTIME_FAILURE;

    context.stdout.print("validated {d} manifest file(s)\n", .{LOADED.manifests.len}) catch
        return CONTEXT.ExitCode.RUNTIME_FAILURE;

    return CONTEXT.ExitCode.SUCCESS;
}
