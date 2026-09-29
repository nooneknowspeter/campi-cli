const STD = @import("std");

const ARTIFACTS = @import("../../artifacts/main.zig");
const CONFIG = @import("../../config/main.zig");
const CONTEXT = @import("../context.zig");
const ENV = @import("../env.zig");
const FS = @import("../../fs/main.zig");
const MANIFEST = @import("../../manifest/main.zig");
const META = @import("../../platforms/meta/main.zig");
const META_ENV = @import("../../platforms/meta/env.zig");
const PARSER = @import("../parser.zig");
const PAYLOAD = @import("../../platforms/meta/payload.zig");
const PLAN = @import("../../plan/main.zig");
const PLATFORMS = @import("../../platforms/main.zig");
const STATE_MODULE = @import("../../state/main.zig");

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

fn buildNewState(
    allocator: STD.mem.Allocator,
    io: STD.Io,
    config: CONFIG.SCHEMA.CONFIG,
    manifest_paths: []const []const u8,
    operations: []const PLAN.SCHEMA.OPERATION,
    previous_state: STATE_MODULE.SCHEMA.STATE,
) !STATE_MODULE.SCHEMA.STATE {
    var meta = STD.ArrayList(STATE_MODULE.SCHEMA.CAMPAIGN).empty;
    var x = STD.ArrayList(STATE_MODULE.SCHEMA.CAMPAIGN).empty;
    var tiktok = STD.ArrayList(STATE_MODULE.SCHEMA.CAMPAIGN).empty;
    var google = STD.ArrayList(STATE_MODULE.SCHEMA.CAMPAIGN).empty;
    var reddit = STD.ArrayList(STATE_MODULE.SCHEMA.CAMPAIGN).empty;
    var linkedin = STD.ArrayList(STATE_MODULE.SCHEMA.CAMPAIGN).empty;

    var platforms = [_]*STD.ArrayList(STATE_MODULE.SCHEMA.CAMPAIGN){
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

                try platforms[PLATFORMS.index(platform.name).?].append(allocator, record);
            };

        for (operations) |operation| {
            if (!STD.mem.eql(u8, operation.platform, platform.name)) continue;

            switch (operation.operation_type) {
                .create => try platforms[PLATFORMS.index(platform.name).?].append(allocator, .{
                    .campaign = operation.campaign,
                    .external_id = operation.external_id,
                    .input_manifest = operation.input_manifest,
                    .manifest_hash = operation.manifest_hash,
                }),
                .update => {
                    for (platforms[PLATFORMS.index(platform.name).?].items) |*record| {
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
        .applied_at = try STATE_MODULE.appliedAt(allocator, io),
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

fn hasPlatformOperations(operations: []const PLAN.SCHEMA.OPERATION, platform: []const u8) bool {
    for (operations) |operation| {
        if (STD.mem.eql(u8, operation.platform, platform))
            return true;
    }

    return false;
}

fn findCampaign(
    loaded_manifests: []const MANIFEST.LoadedManifest,
    operation: PLAN.SCHEMA.OPERATION,
) ?MANIFEST.SCHEMA.CAMPAIGN {
    for (loaded_manifests) |loaded_manifest| {
        if (!STD.mem.eql(u8, loaded_manifest.file_path, operation.input_manifest orelse ""))
            continue;

        for (loaded_manifest.value.campaigns) |campaign| {
            if (STD.mem.eql(u8, campaign.name, operation.campaign))
                return campaign;
        }
    }

    return null;
}

fn imageHashFor(
    client: *const META.Client,
    ad_account_id: []const u8,
    media_urls: []const []const u8,
    artifacts: []const ARTIFACTS.SCHEMA.DownloadedArtifact,
) ![]const u8 {
    const SOURCE = media_urls[0];

    for (artifacts) |artifact| {
        if (STD.mem.eql(u8, artifact.source, SOURCE))
            return client.uploadImage(ad_account_id, SOURCE, artifact.content_type, artifact.bytes);
    }

    return error.MetaCreativeMissing;
}

fn writeMetaOperations(
    allocator: STD.mem.Allocator,
    context: CONTEXT.CommandContext,
    work_dir: STD.Io.Dir,
    loaded_manifests: []const MANIFEST.LoadedManifest,
    operations: []PLAN.SCHEMA.OPERATION,
    overrides: ?[]const ENV.Override,
) !void {
    const ENVIRON = context.environ orelse return error.MetaEnvironmentMissing;

    if (ENV.findMissingEnvVar(ENVIRON, &META_ENV.ENV, overrides)) |missing| {
        context.stderr.print(
            "could not find the {s} environment variable\n",
            .{ENV.effectiveEnvVar(&META_ENV.ENV, missing.key, overrides)},
        ) catch {};

        return error.MetaEnvironmentMissing;
    }

    const TOKEN = ENV.findEnvVarValue(ENVIRON, &META_ENV.ENV, "token", overrides).?;
    const AD_ACCOUNT = ENV.findEnvVarValue(ENVIRON, &META_ENV.ENV, "ad_account_id", overrides).?;
    const PAGE = ENV.findEnvVarValue(ENVIRON, &META_ENV.ENV, "page_id", overrides);
    const INSTAGRAM_ACTOR = ENV.findEnvVarValue(ENVIRON, &META_ENV.ENV, "instagram_actor_id", overrides);
    const CLIENT = META.Client.init(
        allocator,
        context.io,
        ENV.findEnvVarValue(ENVIRON, &META_ENV.ENV, "graph_api_url", overrides).?,
        TOKEN,
    );

    _ = try CLIENT.fetchAccountName(AD_ACCOUNT);
    if (PAGE) |page|
        _ = try CLIENT.fetchPageName(page);
    if (INSTAGRAM_ACTOR) |instagram_actor|
        _ = try CLIENT.fetchPageName(instagram_actor);

    const SOURCES = try ARTIFACTS.collectCreativeSources(allocator, loaded_manifests);
    const LOADED_ARTIFACTS = ARTIFACTS.loadArtifacts(allocator, context, work_dir, SOURCES);

    if (LOADED_ARTIFACTS.invalid)
        return error.ArtifactCouldNotBeLoaded;

    for (operations) |*operation| {
        if (!STD.mem.eql(u8, operation.platform, "meta"))
            continue;

        switch (operation.operation_type) {
            .create, .update => {
                const CAMPAIGN = findCampaign(loaded_manifests, operation.*) orelse
                    return error.MetaCampaignNotFound;

                if (operation.operation_type == .update) {
                    if (operation.external_id) |old_id| {
                        STD.log.scoped(.apply).debug("archiving meta campaign {s}", .{old_id});
                        try CLIENT.archiveCampaign(old_id);
                    }
                }

                const NEW_ID = try CLIENT.createCampaign(
                    AD_ACCOUNT,
                    try PAYLOAD.campaignPayload(allocator, CAMPAIGN),
                );

                STD.log.scoped(.apply).debug("created meta campaign {s}", .{NEW_ID});

                for (CAMPAIGN.ad_groups) |ad_group| {
                    const AD_SET_ID = try CLIENT.createAdSet(
                        AD_ACCOUNT,
                        try PAYLOAD.adSetPayload(allocator, ad_group, NEW_ID),
                    );

                    for (ad_group.ads) |ad| {
                        const IMAGE_HASH = try imageHashFor(
                            &CLIENT,
                            AD_ACCOUNT,
                            ad.CREATIVE.media_urls,
                            LOADED_ARTIFACTS.artifacts,
                        );

                        var destination = PAYLOAD.CREATIVE_DESTINATION{};
                        if (PAGE) |page|
                            destination.page_id = page;
                        if (INSTAGRAM_ACTOR) |instagram_actor|
                            destination.instagram_actor_id = instagram_actor;

                        if (destination.page_id == null and destination.instagram_actor_id == null) {
                            context.stderr.print(
                                "could not find the CAMPI_META_PAGE_ID or CAMPI_META_INSTAGRAM_ACTOR_ID environment variables; one is required to write ad creatives\n",
                                .{},
                            ) catch {};

                            return error.MetaEnvironmentMissing;
                        }

                        const CREATIVE_ID = try CLIENT.createAdCreative(
                            AD_ACCOUNT,
                            try PAYLOAD.creativePayload(allocator, destination, ad, IMAGE_HASH),
                        );

                        _ = try CLIENT.createAd(
                            AD_ACCOUNT,
                            try PAYLOAD.adPayload(allocator, ad, AD_SET_ID, CREATIVE_ID),
                        );
                    }
                }

                operation.external_id = NEW_ID;
            },
            .archive => {
                if (operation.external_id) |old_id| {
                    STD.log.scoped(.apply).debug("archiving meta campaign {s}", .{old_id});
                    try CLIENT.archiveCampaign(old_id);
                }
            },
        }
    }
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

    const MANIFEST_PATHS = MANIFEST.filePaths(context, CONFIG.current_config.?) orelse
        return CONTEXT.ExitCode.RUNTIME_FAILURE;

    const LOADED = MANIFEST.loadAll(allocator, context, WORK_DIR, MANIFEST_PATHS);
    if (LOADED.invalid) return CONTEXT.ExitCode.RUNTIME_FAILURE;

    const state_value: STATE_MODULE.SCHEMA.STATE = switch (STATE_MODULE.load(allocator, context, WORK_DIR, STATE_FILE)) {
        .loaded => |loaded_state| loaded_state.value,
        .missing => STATE_MODULE.EMPTY_STATE,
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
        , .{CONTEXT.Message.Generic.NO_CHANGES}) catch
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

    const lock_result = STATE_MODULE.lockForWrite(context, WORK_DIR);

    const lock_file = switch (lock_result) {
        .acquired => |file| file,
        .held, .failed => return CONTEXT.ExitCode.RUNTIME_FAILURE,
    };
    defer lock_file.close(context.io);

    if (hasPlatformOperations(filtered.items, "meta")) {
        const OVERRIDES = ENV.overridesFromConfig(
            allocator,
            if (CONFIG.current_config) |CONFIGURATION|
                CONFIGURATION.platform_configs.meta
            else
                null,
        ) catch return CONTEXT.ExitCode.RUNTIME_FAILURE;

        writeMetaOperations(
            allocator,
            context,
            WORK_DIR,
            LOADED.manifests,
            filtered.items,
            OVERRIDES,
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
    }

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
        , .{CONTEXT.Message.Generic.PLAN_NOT_COMPUTED}) catch
            return CONTEXT.ExitCode.RUNTIME_FAILURE;

        return CONTEXT.ExitCode.RUNTIME_FAILURE;
    };

    STATE_MODULE.write(context, WORK_DIR, STATE_FILE, NEW_STATE) catch |err| {
        context.stderr.print(
            \\{s}{s}
            \\
            \\{any}
            \\
        , .{ CONTEXT.Message.Generic.STATE_COULD_NOT_BE_WRITTEN, STATE_FILE, err }) catch
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
