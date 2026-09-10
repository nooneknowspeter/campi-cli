const STD = @import("std");

const CONFIG = @import("../../config/main.zig");
const CONTEXT = @import("../context.zig");
const FS = @import("../../fs/main.zig");
const MANIFEST = @import("../../manifest/main.zig");
const PARSER = @import("../parser.zig");
const STATE = @import("../../state/main.zig");

pub const FLAGS = [_]PARSER.FlagDefinition{
    .{
        .long_flag = "dir",
        .short_flag = 'd',
        .is_flag_a_boolean = false,
        .description = "Run command in the specified working directory",
    },
};

const EMPTY_STATE = STATE.SCHEMA.STATE{
    .state_version = "",
    .applied_at = null,
    .manifest_files = &.{},
    .platforms = .{
        .meta = null,
        .x = null,
        .tiktok = null,
        .google = null,
        .reddit = null,
        .linkedin = null,
    },
};

fn buildImportedState(
    allocator: STD.mem.Allocator,
    io: STD.Io,
    config: CONFIG.SCHEMA.CONFIG,
    previous_state: STATE.SCHEMA.STATE,
    platform: []const u8,
    campaign_name: []const u8,
    external_id: []const u8,
) !STATE.SCHEMA.STATE {
    var meta = STD.ArrayList(STATE.SCHEMA.CAMPAIGN).empty;
    var x = STD.ArrayList(STATE.SCHEMA.CAMPAIGN).empty;
    var tiktok = STD.ArrayList(STATE.SCHEMA.CAMPAIGN).empty;
    var google = STD.ArrayList(STATE.SCHEMA.CAMPAIGN).empty;
    var reddit = STD.ArrayList(STATE.SCHEMA.CAMPAIGN).empty;
    var linkedin = STD.ArrayList(STATE.SCHEMA.CAMPAIGN).empty;

    var platforms = [_]*STD.ArrayList(STATE.SCHEMA.CAMPAIGN){
        &meta,
        &x,
        &tiktok,
        &google,
        &reddit,
        &linkedin,
    };

    inline for (STD.meta.fields(@TypeOf(previous_state.platforms))) |field| {
        if (@field(previous_state.platforms, field.name)) |campaigns|
            for (campaigns) |record|
                try platforms[platformIndex(field.name)].append(allocator, record);

        if (STD.mem.eql(u8, field.name, platform))
            try platforms[platformIndex(field.name)].append(allocator, .{
                .campaign = campaign_name,
                .external_id = external_id,
                .input_manifest = null,
                .manifest_hash = "",
            });
    }

    return .{
        .state_version = if (previous_state.state_version.len == 0)
            config.campi_version
        else
            previous_state.state_version,
        .applied_at = try STATE.appliedAt(allocator, io),
        .manifest_files = previous_state.manifest_files,
        .platforms = .{
            .meta = try meta.toOwnedSlice(allocator),
            .x = try x.toOwnedSlice(allocator),
            .tiktok = try tiktok.toOwnedSlice(allocator),
            .google = try google.toOwnedSlice(allocator),
            .reddit = try reddit.toOwnedSlice(allocator),
            .linkedin = try linkedin.toOwnedSlice(allocator),
        },
    };
}

fn platformIndex(name: []const u8) usize {
    if (STD.mem.eql(u8, name, "meta")) return 0;
    if (STD.mem.eql(u8, name, "x")) return 1;
    if (STD.mem.eql(u8, name, "tiktok")) return 2;
    if (STD.mem.eql(u8, name, "google")) return 3;
    if (STD.mem.eql(u8, name, "reddit")) return 4;

    return 5;
}

pub fn run(
    allocator: STD.mem.Allocator,
    context: CONTEXT.CommandContext,
    flags: []const PARSER.ResolvedFlagState,
) CONTEXT.ExitCode {
    if (context.positionals.len != 3) {
        context.stderr.print(
            \\{s}
            \\
        , .{CONTEXT.Message.IMPORT_USAGE}) catch
            return CONTEXT.ExitCode.USAGE_FAILURE;

        return CONTEXT.ExitCode.USAGE_FAILURE;
    }

    const PLATFORM = context.positionals[0];
    const CAMPAIGN = context.positionals[1];
    const EXTERNAL_ID = context.positionals[2];

    if (platformIndex(PLATFORM) == 5) {
        context.stderr.print(
            \\{s}{s}
            \\
        , .{ CONTEXT.Message.IMPORT_UNKNOWN_PLATFORM, PLATFORM }) catch
            return CONTEXT.ExitCode.USAGE_FAILURE;

        return CONTEXT.ExitCode.USAGE_FAILURE;
    }

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

    const STATE_LOCATION = STATE.resolveStateLocation(context, CONFIG.current_config.?) orelse
        return CONTEXT.ExitCode.RUNTIME_FAILURE;

    const STATE_FILE = switch (STATE_LOCATION) {
        .local => |file_name| file_name,
        .cloud => return CONTEXT.ExitCode.RUNTIME_FAILURE,
    };

    const previous_state: STATE.SCHEMA.STATE = switch (STATE.load(allocator, context, WORK_DIR, STATE_FILE)) {
        .loaded => |loaded_state| loaded_state.value,
        .missing => EMPTY_STATE,
        .invalid => return CONTEXT.ExitCode.RUNTIME_FAILURE,
    };

    inline for (STD.meta.fields(@TypeOf(previous_state.platforms))) |field| {
        if (STD.mem.eql(u8, field.name, PLATFORM)) {
            if (@field(previous_state.platforms, field.name)) |campaigns| {
                for (campaigns) |record| {
                    if (STD.mem.eql(u8, record.campaign, CAMPAIGN)) {
                        context.stderr.print(
                            \\{s}{s}/{s}
                            \\
                        , .{ CONTEXT.Message.IMPORT_ALREADY_IMPORTED, PLATFORM, CAMPAIGN }) catch
                            return CONTEXT.ExitCode.RUNTIME_FAILURE;

                        return CONTEXT.ExitCode.RUNTIME_FAILURE;
                    }
                }
            }
        }
    }

    const lock_result = STATE.lockForWrite(context, WORK_DIR);

    const lock_file = switch (lock_result) {
        .acquired => |file| file,
        .held, .failed => return CONTEXT.ExitCode.RUNTIME_FAILURE,
    };
    defer lock_file.close(context.io);

    const NEW_STATE = buildImportedState(
        allocator,
        context.io,
        CONFIG.current_config.?,
        previous_state,
        PLATFORM,
        CAMPAIGN,
        EXTERNAL_ID,
    ) catch {
        context.stderr.print(
            \\{s}
            \\
        , .{CONTEXT.Message.PLAN_NOT_COMPUTED}) catch
            return CONTEXT.ExitCode.RUNTIME_FAILURE;

        return CONTEXT.ExitCode.RUNTIME_FAILURE;
    };

    STATE.write(context, WORK_DIR, STATE_FILE, NEW_STATE) catch |err| {
        context.stderr.print(
            \\{s}{s}
            \\
            \\{any}
            \\
        , .{ CONTEXT.Message.STATE_COULD_NOT_BE_WRITTEN, STATE_FILE, err }) catch
            return CONTEXT.ExitCode.RUNTIME_FAILURE;

        return CONTEXT.ExitCode.RUNTIME_FAILURE;
    };

    context.stdout.print("imported: {s}/{s}\n", .{ PLATFORM, CAMPAIGN }) catch
        return CONTEXT.ExitCode.RUNTIME_FAILURE;

    return CONTEXT.ExitCode.SUCCESS;
}
