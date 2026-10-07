const STD = @import("std");

const CONFIG = @import("../../config/main.zig");
const CONTEXT = @import("../../cli/context.zig");
const ENV = @import("../../cli/env.zig");
const PARSER = @import("../../cli/parser.zig");
const META_ENV = @import("env.zig");
const META = @import("main.zig");

pub fn run(
    allocator: STD.mem.Allocator,
    context: CONTEXT.CommandContext,
    flags: []const PARSER.ResolvedFlagState,
) CONTEXT.ExitCode {
    _ = flags;

    const ENVIRON = context.environ orelse {
        context.stderr.print(
            "could not read the environment\n",
            .{},
        ) catch return CONTEXT.ExitCode.RUNTIME_FAILURE;

        return CONTEXT.ExitCode.RUNTIME_FAILURE;
    };

    const OVERRIDES = ENV.overridesFromConfig(
        allocator,
        if (CONFIG.current_config) |CONFIGURATION|
            CONFIGURATION.platform_configs.meta
        else
            null,
    ) catch {
        context.stderr.print(
            "could not build the environment variable overrides\n",
            .{},
        ) catch return CONTEXT.ExitCode.RUNTIME_FAILURE;

        return CONTEXT.ExitCode.RUNTIME_FAILURE;
    };

    if (ENV.findMissingEnvVar(ENVIRON, &META_ENV.ENV, OVERRIDES)) |missing| {
        context.stderr.print(
            "could not find the {s} environment variable\n",
            .{ENV.effectiveEnvVar(&META_ENV.ENV, missing.key, OVERRIDES)},
        ) catch return CONTEXT.ExitCode.RUNTIME_FAILURE;

        return CONTEXT.ExitCode.RUNTIME_FAILURE;
    }

    const TOKEN = ENV.findEnvVarValue(ENVIRON, &META_ENV.ENV, "token", OVERRIDES).?;
    const AD_ACCOUNT = ENV.findEnvVarValue(ENVIRON, &META_ENV.ENV, "ad_account_id", OVERRIDES).?;

    const CLIENT = META.Client.init(
        allocator,
        context.io,
        ENV.findEnvVarValue(ENVIRON, &META_ENV.ENV, "graph_api_url", OVERRIDES).?,
        TOKEN,
    );

    const ACCOUNT_NAME = CLIENT.fetchAccountName(AD_ACCOUNT) catch {
        context.stderr.print("could not fetch the meta ad account\n", .{}) catch
            return CONTEXT.ExitCode.RUNTIME_FAILURE;

        return CONTEXT.ExitCode.RUNTIME_FAILURE;
    };
    defer allocator.free(ACCOUNT_NAME);

    const CAMPAIGNS = CLIENT.fetchCampaigns(AD_ACCOUNT) catch {
        context.stderr.print("could not fetch meta campaigns\n", .{}) catch
            return CONTEXT.ExitCode.RUNTIME_FAILURE;

        return CONTEXT.ExitCode.RUNTIME_FAILURE;
    };
    defer allocator.free(CAMPAIGNS);

    context.stdout.print("Account: {s} (act_{s})\n", .{ ACCOUNT_NAME, AD_ACCOUNT }) catch
        return CONTEXT.ExitCode.RUNTIME_FAILURE;

    const PAGE_ID = ENV.findEnvVarValue(ENVIRON, &META_ENV.ENV, "page_id", OVERRIDES);

    if (PAGE_ID) |page_id| {
        if (CLIENT.fetchLinkedInstagramAccounts(page_id)) |accounts| {
            defer {
                for (accounts) |account| {
                    allocator.free(account.id);
                    if (account.ig_id) |ig_id| allocator.free(ig_id);
                    if (account.username) |username| allocator.free(username);
                    if (account.name) |name| allocator.free(name);
                }
                allocator.free(accounts);
            }

            formatInstagramAccounts(context, accounts) catch
                return CONTEXT.ExitCode.RUNTIME_FAILURE;
        } else |_| {
            context.stderr.print(
                "could not fetch linked instagram accounts for the configured page\n",
                .{},
            ) catch return CONTEXT.ExitCode.RUNTIME_FAILURE;
        }
    }

    if (CAMPAIGNS.len == 0) {
        context.stdout.print("no campaigns found\n", .{}) catch
            return CONTEXT.ExitCode.RUNTIME_FAILURE;

        return CONTEXT.ExitCode.SUCCESS;
    }

    formatCampaigns(context, CAMPAIGNS) catch
        return CONTEXT.ExitCode.RUNTIME_FAILURE;

    return CONTEXT.ExitCode.SUCCESS;
}

pub fn formatCampaigns(
    context: CONTEXT.CommandContext,
    campaigns: []const META.Campaign,
) !void {
    for (campaigns) |campaign| {
        const OBJECTIVE = if (STD.mem.startsWith(u8, campaign.objective, "OUTCOME_"))
            campaign.objective["OUTCOME_".len..]
        else
            campaign.objective;

        try context.stdout.print("{s} [{s}] {s}\n", .{ campaign.name, OBJECTIVE, campaign.status });
    }
}

pub fn formatInstagramAccounts(
    context: CONTEXT.CommandContext,
    accounts: []const META.INSTAGRAM_ACCOUNT,
) !void {
    try context.stdout.print("Linked instagram accounts:\n", .{});

    if (accounts.len == 0) {
        try context.stdout.print("  none found\n", .{});

        return;
    }

    for (accounts) |account| {
        try context.stdout.print("  ", .{});

        if (account.name) |name| {
            try context.stdout.print("{s} ", .{name});
            if (account.username) |username|
                try context.stdout.print("(@{s}) ", .{username});
        } else if (account.username) |username| {
            try context.stdout.print("@{s} ", .{username});
        }

        try context.stdout.print("id={s}", .{account.id});

        if (account.ig_id) |ig_id| {
            if (!STD.mem.eql(u8, ig_id, account.id))
                try context.stdout.print(" ig_id={s}", .{ig_id});
        }

        try context.stdout.print("\n", .{});
    }
}
