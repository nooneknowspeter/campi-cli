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
    if (PARSER.hasFlag(flags, "interactive")) {
        context.stderr.print(
            \\{s}
            \\
        , .{CONTEXT.Message.Generic.NOT_IMPLEMENTED}) catch
            return CONTEXT.ExitCode.RUNTIME_FAILURE;

        return CONTEXT.ExitCode.RUNTIME_FAILURE;
    }

    var path_buffer: [STD.Io.Dir.max_path_bytes]u8 = undefined;

    const DIR_PATH = FS.dirPath(context, flags, &path_buffer) catch {
        context.stderr.print(
            \\{s}
            \\
        , .{CONTEXT.Message.Generic.COULD_NOT_DETERMINE_WORKING_DIRECTORY}) catch
            return CONTEXT.ExitCode.RUNTIME_FAILURE;

        return CONTEXT.ExitCode.RUNTIME_FAILURE;
    };

    const WORK_DIR = FS.openWorkDir(context, DIR_PATH) catch {
        context.stderr.print(
            \\{s}{s}
            \\
        , .{ CONTEXT.Message.Generic.WORKING_DIRECTORY_DOES_NOT_EXIST, DIR_PATH }) catch
            return CONTEXT.ExitCode.RUNTIME_FAILURE;

        return CONTEXT.ExitCode.RUNTIME_FAILURE;
    };
    defer WORK_DIR.close(context.io);

    const PROJECT_NAME = STD.Io.Dir.path.basename(DIR_PATH);

    // scaffold when no config file is present
    WORK_DIR.access(context.io, "config.campi", .{}) catch {
        FS.writeFiles(context, WORK_DIR, PROJECT_NAME) catch {
            context.stderr.print(
                \\{s}{s}
                \\
            , .{ CONTEXT.Message.Generic.CONFIG_COULD_NOT_BE_WRITTEN, DIR_PATH }) catch
                return CONTEXT.ExitCode.RUNTIME_FAILURE;

            return CONTEXT.ExitCode.RUNTIME_FAILURE;
        };

        context.stdout.print(
            \\initialized campi in {s}
            \\created config.campi
            \\created example.manifest.campi
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
        , .{ CONTEXT.Message.Generic.CONFIG_COULD_NOT_BE_LOADED, DIR_PATH }) catch
            return CONTEXT.ExitCode.RUNTIME_FAILURE;

        return CONTEXT.ExitCode.RUNTIME_FAILURE;
    };

    context.stdout.print(
        \\campi is already initialized in {s}
        \\nothing to do; run the plan command to preview changes or the apply command to provision campi data
        \\
    , .{DIR_PATH}) catch
        return CONTEXT.ExitCode.RUNTIME_FAILURE;

    return CONTEXT.ExitCode.SUCCESS;
}
