const STD = @import("std");

const CONFIG = @import("../../config/main.zig");
const CONTEXT = @import("../context.zig");
const FS = @import("../../fs/main.zig");
const PARSER = @import("../parser.zig");
const PLATFORMS = @import("../../platforms/main.zig");

pub const FLAGS = [_]PARSER.FlagDefinition{
    .{
        .long_flag = "dir",
        .short_flag = 'd',
        .is_flag_a_boolean = false,
        .description = "Run command in the specified working directory",
    },
};

const PLATFORM_COMMANDS = [_]struct {
    name: []const u8,
    run: *const fn (
        STD.mem.Allocator,
        CONTEXT.CommandContext,
        []const PARSER.ResolvedFlagState,
    ) CONTEXT.ExitCode,
}{
    .{ .name = "meta", .run = @import("../../platforms/meta/command.zig").run },
    .{ .name = "tiktok", .run = @import("../../platforms/tiktok/command.zig").run },
    .{ .name = "x", .run = @import("../../platforms/x/command.zig").run },
    .{ .name = "google", .run = @import("../../platforms/google/command.zig").run },
    .{ .name = "reddit", .run = @import("../../platforms/reddit/command.zig").run },
    .{ .name = "linkedin", .run = @import("../../platforms/linkedin/command.zig").run },
};

pub fn run(
    allocator: STD.mem.Allocator,
    context: CONTEXT.CommandContext,
    flags: []const PARSER.ResolvedFlagState,
) CONTEXT.ExitCode {
    if (context.positionals.len == 0) {
        context.stderr.print("usage: campi-cli platform <name> [ARGS]\nplatforms: ", .{}) catch
            return CONTEXT.ExitCode.USAGE_FAILURE;

        for (PLATFORMS.NAMES, 0..) |name, i| {
            if (i > 0) context.stderr.print(", ", .{}) catch
                return CONTEXT.ExitCode.USAGE_FAILURE;
            context.stderr.print("{s}", .{name}) catch
                return CONTEXT.ExitCode.USAGE_FAILURE;
        }

        context.stderr.print("\n", .{}) catch
            return CONTEXT.ExitCode.USAGE_FAILURE;

        return CONTEXT.ExitCode.USAGE_FAILURE;
    }

    const NAME = context.positionals[0];

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

    _ = CONFIG.loadOptional(allocator, context, WORK_DIR) catch {
        context.stderr.print(
            \\{s}{s}
            \\
        , .{ CONTEXT.Message.Generic.CONFIG_COULD_NOT_BE_LOADED, DIR_PATH }) catch
            return CONTEXT.ExitCode.RUNTIME_FAILURE;

        return CONTEXT.ExitCode.RUNTIME_FAILURE;
    };

    for (PLATFORM_COMMANDS) |entry| {
        if (STD.mem.eql(u8, entry.name, NAME))
            return entry.run(allocator, context, flags);
    }

    context.stderr.print("unknown platform: {s}\n", .{NAME}) catch
        return CONTEXT.ExitCode.USAGE_FAILURE;

    return CONTEXT.ExitCode.USAGE_FAILURE;
}
