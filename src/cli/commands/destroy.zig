const STD = @import("std");

const CONFIG = @import("../../config/main.zig");
const CONTEXT = @import("../context.zig");
const FS = @import("../../fs/main.zig");
const MANIFEST = @import("../../manifest/main.zig");
const META = @import("../../platforms/meta/main.zig");
const PARSER = @import("../parser.zig");
const PLAN = @import("../../plan/main.zig");
const STATE = @import("../../state/main.zig");

pub const FLAGS = [_]PARSER.FlagDefinition{
    .{
        .long_flag = "write",
        .short_flag = 'w',
        .is_flag_a_boolean = true,
        .description = "Archive the campaigns and clear state",
    },
    .{
        .long_flag = "dir",
        .short_flag = 'd',
        .is_flag_a_boolean = false,
        .description = "Run command in the specified working directory",
    },
};

fn buildArchiveOperations(
    allocator: STD.mem.Allocator,
    previous_state: STATE.SCHEMA.STATE,
) ![]PLAN.SCHEMA.OPERATION {
    var operations = STD.ArrayList(PLAN.SCHEMA.OPERATION).empty;

    inline for (STD.meta.fields(@TypeOf(previous_state.platforms))) |platform| {
        if (@field(previous_state.platforms, platform.name)) |campaigns| {
            for (campaigns) |record| {
                if (record.external_id == null) continue;

                try operations.append(allocator, .{
                    .platform = platform.name,
                    .campaign = record.campaign,
                    .operation_type = .archive,
                    .external_id = record.external_id,
                    .input_manifest = record.input_manifest,
                    .manifest_hash = "",
                });
            }
        }
    }

    return operations.toOwnedSlice(allocator);
}

fn printOperations(
    context: CONTEXT.CommandContext,
    operations: []const PLAN.SCHEMA.OPERATION,
) CONTEXT.ExitCode {
    var current_platform: ?[]const u8 = null;

    for (operations) |operation| {
        if (current_platform == null or !STD.mem.eql(u8, current_platform.?, operation.platform)) {
            context.stdout.print("{s}:\n", .{operation.platform}) catch
                return CONTEXT.ExitCode.RUNTIME_FAILURE;

            current_platform = operation.platform;
        }

        context.stdout.print("  - archive {s}\n", .{operation.campaign}) catch
            return CONTEXT.ExitCode.RUNTIME_FAILURE;
    }

    return CONTEXT.ExitCode.SUCCESS;
}

fn clearedState(
    allocator: STD.mem.Allocator,
    io: STD.Io,
    config: CONFIG.SCHEMA.CONFIG,
    previous_state: STATE.SCHEMA.STATE,
) !STATE.SCHEMA.STATE {
    return .{
        .state_version = if (previous_state.state_version.len == 0)
            config.campi_version
        else
            previous_state.state_version,
        .applied_at = try STATE.appliedAt(allocator, io),
        .manifest_files = previous_state.manifest_files,
        .platforms = .{
            .meta = null,
            .x = null,
            .tiktok = null,
            .google = null,
            .reddit = null,
            .linkedin = null,
        },
    };
}

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

    const PREVIOUS_STATE: STATE.SCHEMA.STATE = switch (STATE.load(allocator, context, WORK_DIR, STATE_FILE)) {
        .loaded => |loaded_state| loaded_state.value,
        .missing => STATE.EMPTY_STATE,
        .invalid => return CONTEXT.ExitCode.RUNTIME_FAILURE,
    };

    const OPERATIONS = buildArchiveOperations(allocator, PREVIOUS_STATE) catch {
        context.stderr.print(
            \\{s}
            \\
        , .{CONTEXT.Message.Generic.PLAN_NOT_COMPUTED}) catch
            return CONTEXT.ExitCode.RUNTIME_FAILURE;

        return CONTEXT.ExitCode.RUNTIME_FAILURE;
    };

    if (OPERATIONS.len == 0) {
        context.stdout.print(
            \\{s}
            \\
        , .{CONTEXT.Message.Generic.NO_CHANGES}) catch
            return CONTEXT.ExitCode.RUNTIME_FAILURE;

        return CONTEXT.ExitCode.SUCCESS;
    }

    if (!PARSER.hasFlag(flags, "write")) {
        switch (printOperations(context, OPERATIONS)) {
            .SUCCESS => {},
            else => |code| return code,
        }

        context.stdout.print("dry run: would destroy {d} campaign(s)\n", .{OPERATIONS.len}) catch
            return CONTEXT.ExitCode.RUNTIME_FAILURE;

        return CONTEXT.ExitCode.PENDING_UPDATES;
    }

    const LOCK_RESULT = STATE.lockForWrite(context, WORK_DIR);

    const LOCK_FILE = switch (LOCK_RESULT) {
        .acquired => |file| file,
        .held, .failed => return CONTEXT.ExitCode.RUNTIME_FAILURE,
    };
    defer LOCK_FILE.close(context.io);

    const NO_MANIFESTS: []const MANIFEST.LoadedManifest = &.{};

    META.writeOperations(
        allocator,
        context,
        WORK_DIR,
        NO_MANIFESTS,
        OPERATIONS,
    ) catch |err| {
        if (err == error.MetaEnvironmentMissing)
            return CONTEXT.ExitCode.RUNTIME_FAILURE;

        context.stderr.print(
            \\{s}{any}
            \\
        , .{ CONTEXT.Message.Platform.META_COULD_NOT_BE_WRITTEN, err }) catch
            return CONTEXT.ExitCode.RUNTIME_FAILURE;

        return CONTEXT.ExitCode.RUNTIME_FAILURE;
    };

    const NEW_STATE = clearedState(
        allocator,
        context.io,
        CONFIG.current_config.?,
        PREVIOUS_STATE,
    ) catch {
        context.stderr.print(
            \\{s}
            \\
        , .{CONTEXT.Message.Generic.PLAN_NOT_COMPUTED}) catch
            return CONTEXT.ExitCode.RUNTIME_FAILURE;

        return CONTEXT.ExitCode.RUNTIME_FAILURE;
    };

    STATE.write(context, WORK_DIR, STATE_FILE, NEW_STATE) catch |err| {
        context.stderr.print(
            \\{s}{s}
            \\
            \\{any}
            \\
        , .{ CONTEXT.Message.Generic.STATE_COULD_NOT_BE_WRITTEN, STATE_FILE, err }) catch
            return CONTEXT.ExitCode.RUNTIME_FAILURE;

        return CONTEXT.ExitCode.RUNTIME_FAILURE;
    };

    switch (printOperations(context, OPERATIONS)) {
        .SUCCESS => {},
        else => |code| return code,
    }

    context.stdout.print("destroyed {d} campaign(s)\n", .{OPERATIONS.len}) catch
        return CONTEXT.ExitCode.RUNTIME_FAILURE;

    return CONTEXT.ExitCode.SUCCESS;
}
