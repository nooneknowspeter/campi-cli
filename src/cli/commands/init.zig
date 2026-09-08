const STD = @import("std");

const CONFIG = @import("../../config/main.zig");
const CONTEXT = @import("../context.zig");
const FS = @import("../../fs/main.zig");
const PARSER = @import("../parser.zig");

pub const FLAGS = [_]PARSER.FlagDefinition{
    .{
        .long_flag = "interactive",
        .short_flag = 'i',
        .is_flag_a_boolean = true,
        .description = "Run command in an interactive state",
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

    const PROJECT_NAME = STD.Io.Dir.path.basename(DIR_PATH);

    // scaffold when no config file is present
    WORK_DIR.access(context.io, "config.campi.zon", .{}) catch {
        FS.writeFiles(context, WORK_DIR, PROJECT_NAME) catch {
            context.stderr.print(
                \\{s}{s}
                \\
            , .{ CONTEXT.Message.CONFIG_COULD_NOT_BE_WRITTEN, DIR_PATH }) catch
                return CONTEXT.ExitCode.RUNTIME_FAILURE;

            return CONTEXT.ExitCode.RUNTIME_FAILURE;
        };

        context.stdout.print(
            \\initialized campi in {s}
            \\created config.campi.zon
            \\created example.manifest.campi.zon
            \\
        , .{DIR_PATH}) catch
            return CONTEXT.ExitCode.RUNTIME_FAILURE;

        return CONTEXT.ExitCode.SUCCESS;
    };

    // a config file is present; load it into the config module
    CONFIG.load(allocator, context, WORK_DIR) catch {
        context.stderr.print(
            \\{s}{s}
            \\
        , .{ CONTEXT.Message.CONFIG_COULD_NOT_BE_LOADED, DIR_PATH }) catch
            return CONTEXT.ExitCode.RUNTIME_FAILURE;

        return CONTEXT.ExitCode.RUNTIME_FAILURE;
    };

    context.stdout.print(
        \\{s}
        \\
    , .{CONTEXT.Message.LOADED_CONFIG}) catch
        return CONTEXT.ExitCode.RUNTIME_FAILURE;

    return CONTEXT.ExitCode.SUCCESS;
}
