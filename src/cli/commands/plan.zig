const STD = @import("std");

const CONFIG = @import("../../config/main.zig");
const CONTEXT = @import("../context.zig");
const FS = @import("../../fs/main.zig");
const MANIFEST = @import("../../manifest/main.zig");
const PARSER = @import("../parser.zig");
const PLAN = @import("../../plan/main.zig");
const STATE = @import("../../state/main.zig");

pub const FLAGS = [_]PARSER.FlagDefinition{
    .{
        .long_flag = "export",
        .short_flag = null,
        .is_flag_a_boolean = true,
        .description = "Export the plan",
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

    const STATE_LOCATION = STATE.resolveStateLocation(context, CONFIG.current_config.?) orelse
        return CONTEXT.ExitCode.RUNTIME_FAILURE;

    const STATE_FILE = switch (STATE_LOCATION) {
        .local => |file_name| file_name,
        .cloud => return CONTEXT.ExitCode.RUNTIME_FAILURE,
    };

    const MANIFEST_PATHS = MANIFEST.filePaths(context, CONFIG.current_config.?) orelse
        return CONTEXT.ExitCode.RUNTIME_FAILURE;

    const LOADED = MANIFEST.loadAll(allocator, context, WORK_DIR, MANIFEST_PATHS);
    if (LOADED.invalid) return CONTEXT.ExitCode.RUNTIME_FAILURE;

    const state_value: ?STATE.SCHEMA.STATE = switch (STATE.load(allocator, context, WORK_DIR, STATE_FILE)) {
        .loaded => |loaded_state| loaded_state.value,
        .missing => null,
        .invalid => return CONTEXT.ExitCode.RUNTIME_FAILURE,
    };

    const PLAN_VALUE = PLAN.computePlan(
        allocator,
        CONFIG.current_config.?,
        LOADED.manifests,
        state_value,
    ) catch {
        context.stderr.print(
            \\{s}
            \\
        , .{CONTEXT.Message.Generic.PLAN_NOT_COMPUTED}) catch
            return CONTEXT.ExitCode.RUNTIME_FAILURE;

        return CONTEXT.ExitCode.RUNTIME_FAILURE;
    };

    if (PARSER.hasFlag(flags, "export")) {
        var writer = STD.Io.Writer.Allocating.init(allocator);
        defer writer.deinit();

        STD.zon.stringify.serialize(
            PLAN_VALUE,
            .{ .whitespace = true },
            &writer.writer,
        ) catch {
            context.stderr.print(
                \\{s}
                \\
            , .{CONTEXT.Message.Generic.PLAN_NOT_COMPUTED}) catch
                return CONTEXT.ExitCode.RUNTIME_FAILURE;

            return CONTEXT.ExitCode.RUNTIME_FAILURE;
        };

        context.stdout.print("{s}\n", .{writer.toArrayList().items}) catch
            return CONTEXT.ExitCode.RUNTIME_FAILURE;

        if (PLAN_VALUE.operations.len == 0) return CONTEXT.ExitCode.SUCCESS;

        return CONTEXT.ExitCode.PENDING_UPDATES;
    }

    if (PLAN_VALUE.operations.len == 0) {
        context.stdout.print(
            \\{s}
            \\
        , .{CONTEXT.Message.Generic.NO_CHANGES}) catch
            return CONTEXT.ExitCode.RUNTIME_FAILURE;

        return CONTEXT.ExitCode.SUCCESS;
    }

    var current_platform: ?[]const u8 = null;

    for (PLAN_VALUE.operations) |operation| {
        if (current_platform == null or !STD.mem.eql(u8, current_platform.?, operation.platform)) {
            current_platform = operation.platform;

            var count: usize = 0;

            for (PLAN_VALUE.operations) |candidate| {
                if (STD.mem.eql(u8, candidate.platform, operation.platform)) count += 1;
            }

            context.stdout.print("{s}: {d} change(s)\n", .{ operation.platform, count }) catch
                return CONTEXT.ExitCode.RUNTIME_FAILURE;
        }

        const SYMBOL = switch (operation.operation_type) {
            .create => "+",
            .update => "~",
            .archive => "-",
        };

        context.stdout.print("  {s} {s}\n", .{ SYMBOL, operation.campaign }) catch
            return CONTEXT.ExitCode.RUNTIME_FAILURE;
    }

    return CONTEXT.ExitCode.PENDING_UPDATES;
}
