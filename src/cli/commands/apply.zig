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
        .long_flag = "exclude",
        .short_flag = null,
        .is_flag_a_boolean = false,
        .description = "Exclude a campaign by name from the apply",
    },
    .{
        .long_flag = "write",
        .short_flag = 'w',
        .is_flag_a_boolean = true,
        .description = "Apply the plan and persist state",
    },
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

fn buildNewState(
    allocator: STD.mem.Allocator,
    io: STD.Io,
    config: CONFIG.SCHEMA.CONFIG,
    manifest_paths: []const []const u8,
    operations: []const PLAN.SCHEMA.OPERATION,
    previous_state: STATE.SCHEMA.STATE,
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

    inline for (STD.meta.fields(@TypeOf(previous_state.platforms))) |platform| {
        if (@field(previous_state.platforms, platform.name)) |campaigns|
            for (campaigns) |record| {
                var archived = false;

                for (operations) |operation| {
                    if (operation.operation_type == .archive and
                        STD.mem.eql(u8, operation.platform, platform.name) and
                        STD.mem.eql(u8, operation.campaign, record.campaign))
                    {
                        archived = true;
                        break;
                    }
                }

                if (archived) continue;

                try platforms[platform_index(platform.name)].append(allocator, record);
            };

        for (operations) |operation| {
            if (!STD.mem.eql(u8, operation.platform, platform.name)) continue;

            switch (operation.operation_type) {
                .create => try platforms[platform_index(platform.name)].append(allocator, .{
                    .campaign = operation.campaign,
                    .external_id = operation.external_id,
                    .input_manifest = operation.input_manifest,
                    .manifest_hash = operation.manifest_hash,
                }),
                .update => {
                    for (platforms[platform_index(platform.name)].items) |*record| {
                        if (STD.mem.eql(u8, record.campaign, operation.campaign)) {
                            record.external_id = operation.external_id;
                            record.input_manifest = operation.input_manifest;
                            record.manifest_hash = operation.manifest_hash;
                        }
                    }
                },
                .archive => {},
            }
        }
    }

    return .{
        .state_version = if (previous_state.state_version.len == 0)
            config.campi_version
        else
            previous_state.state_version,
        .applied_at = try STATE.appliedAt(allocator, io),
        .manifest_files = manifest_paths,
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

fn platform_index(name: []const u8) usize {
    if (STD.mem.eql(u8, name, "meta")) return 0;
    if (STD.mem.eql(u8, name, "x")) return 1;
    if (STD.mem.eql(u8, name, "tiktok")) return 2;
    if (STD.mem.eql(u8, name, "google")) return 3;
    if (STD.mem.eql(u8, name, "reddit")) return 4;

    return 5;
}

fn printOperations(context: CONTEXT.CommandContext, operations: []const PLAN.SCHEMA.OPERATION, verb: []const u8) CONTEXT.ExitCode {
    var current_platform: ?[]const u8 = null;

    for (operations) |operation| {
        if (current_platform == null or !STD.mem.eql(u8, current_platform.?, operation.platform)) {
            context.stdout.print("{s}:\n", .{operation.platform}) catch
                return CONTEXT.ExitCode.RUNTIME_FAILURE;

            current_platform = operation.platform;
        }

        const SYMBOL = switch (operation.operation_type) {
            .create => "+",
            .update => "~",
            .archive => "-",
        };

        context.stdout.print("  {s} {s} {s}\n", .{ SYMBOL, verb, operation.campaign }) catch
            return CONTEXT.ExitCode.RUNTIME_FAILURE;
    }

    return CONTEXT.ExitCode.SUCCESS;
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

    const MANIFEST_PATHS = MANIFEST.filePaths(context, CONFIG.current_config.?) orelse
        return CONTEXT.ExitCode.RUNTIME_FAILURE;

    const LOADED = MANIFEST.loadAll(allocator, context, WORK_DIR, MANIFEST_PATHS);
    if (LOADED.invalid) return CONTEXT.ExitCode.RUNTIME_FAILURE;

    const state_value: STATE.SCHEMA.STATE = switch (STATE.load(allocator, context, WORK_DIR, STATE_FILE)) {
        .loaded => |loaded_state| loaded_state.value,
        .missing => EMPTY_STATE,
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
        , .{CONTEXT.Message.PLAN_NOT_COMPUTED}) catch
            return CONTEXT.ExitCode.RUNTIME_FAILURE;

        return CONTEXT.ExitCode.RUNTIME_FAILURE;
    };

    var filtered = STD.ArrayList(PLAN.SCHEMA.OPERATION).empty;

    for (PLAN_VALUE.operations) |operation| {
        var excluded = false;

        for (flags) |flag| {
            if (!STD.mem.eql(u8, flag.long_flag, "exclude")) continue;

            if (flag.value) |excluded_name| {
                if (STD.mem.eql(u8, excluded_name, operation.campaign)) {
                    excluded = true;
                    break;
                }
            }
        }

        if (excluded) continue;

        filtered.append(allocator, operation) catch
            return CONTEXT.ExitCode.RUNTIME_FAILURE;
    }

    if (filtered.items.len == 0) {
        context.stdout.print(
            \\{s}
            \\
        , .{CONTEXT.Message.NO_CHANGES}) catch
            return CONTEXT.ExitCode.RUNTIME_FAILURE;

        return CONTEXT.ExitCode.SUCCESS;
    }

    if (!PARSER.hasFlag(flags, "write")) {
        switch (printOperations(context, filtered.items, "apply")) {
            .SUCCESS => {},
            else => |code| return code,
        }

        context.stdout.print("dry run: would apply {d} change(s)\n", .{filtered.items.len}) catch
            return CONTEXT.ExitCode.RUNTIME_FAILURE;

        return CONTEXT.ExitCode.PENDING_UPDATES;
    }

    const lock_result = STATE.lockForWrite(context, WORK_DIR);

    const lock_file = switch (lock_result) {
        .acquired => |file| file,
        .held, .failed => return CONTEXT.ExitCode.RUNTIME_FAILURE,
    };
    defer lock_file.close(context.io);

    const NEW_STATE = buildNewState(
        allocator,
        context.io,
        CONFIG.current_config.?,
        MANIFEST_PATHS,
        filtered.items,
        state_value,
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

    switch (printOperations(context, filtered.items, "applied")) {
        .SUCCESS => {},
        else => |code| return code,
    }

    context.stdout.print("applied {d} change(s)\n", .{filtered.items.len}) catch
        return CONTEXT.ExitCode.RUNTIME_FAILURE;

    return CONTEXT.ExitCode.SUCCESS;
}
