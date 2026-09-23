const STD = @import("std");

const CONFIG = @import("../../config/main.zig");
const CONTEXT = @import("../context.zig");
const FS = @import("../../fs/main.zig");
const PARSER = @import("../parser.zig");
const STATE_MODULE = @import("../../state/main.zig");

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

    CONFIG.load(allocator, context, WORK_DIR) catch {
        context.stderr.print(
            \\{s}
            \\
        , .{CONTEXT.Message.Generic.CONFIG_NOT_FOUND}) catch
            return CONTEXT.ExitCode.RUNTIME_FAILURE;

        return CONTEXT.ExitCode.RUNTIME_FAILURE;
    };

    const STATE_LOCATION = STATE_MODULE.resolveStateLocation(context, CONFIG.current_config.?) orelse
        return CONTEXT.ExitCode.RUNTIME_FAILURE;

    const STATE_FILE = switch (STATE_LOCATION) {
        .local => |file_name| file_name,
        .cloud => return CONTEXT.ExitCode.RUNTIME_FAILURE,
    };

    switch (STATE_MODULE.acquireLock(context, WORK_DIR)) {
        .available => STD.log.debug("state lock is available", .{}),
        .held => STD.log.debug("state lock is held by another process", .{}),
        .failed => return CONTEXT.ExitCode.RUNTIME_FAILURE,
    }

    switch (STATE_MODULE.load(allocator, context, WORK_DIR, STATE_FILE)) {
        .loaded => |loaded_state| {
            context.stdout.print("state version: {s}\n", .{loaded_state.value.state_version}) catch
                return CONTEXT.ExitCode.RUNTIME_FAILURE;

            if (loaded_state.value.applied_at) |applied_at|
                context.stdout.print("applied at: {s}\n", .{applied_at}) catch
                    return CONTEXT.ExitCode.RUNTIME_FAILURE
            else
                context.stdout.print("applied at: never\n", .{}) catch
                    return CONTEXT.ExitCode.RUNTIME_FAILURE;

            inline for (STD.meta.fields(@TypeOf(loaded_state.value.platforms))) |platform| {
                if (@field(loaded_state.value.platforms, platform.name)) |campaigns| {
                    context.stdout.print("{s}: {d} campaign(s)\n", .{ platform.name, campaigns.len }) catch
                        return CONTEXT.ExitCode.RUNTIME_FAILURE;
                }
            }

            return CONTEXT.ExitCode.SUCCESS;
        },
        .missing => {
            context.stdout.print("no state recorded yet\n", .{}) catch
                return CONTEXT.ExitCode.RUNTIME_FAILURE;

            return CONTEXT.ExitCode.SUCCESS;
        },
        .invalid => return CONTEXT.ExitCode.RUNTIME_FAILURE,
    }
}
