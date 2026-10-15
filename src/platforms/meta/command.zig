const STD = @import("std");

const CONFIG = @import("../../config/main.zig");
const CONTEXT = @import("../../cli/context.zig");
const ENV = @import("../../cli/env.zig");
const PARSER = @import("../../cli/parser.zig");
const META_ENV = @import("env.zig");
const META = @import("main.zig");
const SCHEMA = META.SCHEMA;

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

    const PAGES = CLIENT.fetchPages() catch {
        context.stderr.print("could not fetch meta pages\n", .{}) catch
            return CONTEXT.ExitCode.RUNTIME_FAILURE;

        return CONTEXT.ExitCode.RUNTIME_FAILURE;
    };
    defer SCHEMA.freePages(allocator, PAGES);

    const CAMPAIGNS = CLIENT.fetchCampaigns(AD_ACCOUNT) catch {
        context.stderr.print("could not fetch meta campaigns\n", .{}) catch
            return CONTEXT.ExitCode.RUNTIME_FAILURE;

        return CONTEXT.ExitCode.RUNTIME_FAILURE;
    };
    defer SCHEMA.freeCampaigns(allocator, CAMPAIGNS);

    const AD_SETS = CLIENT.fetchAdSets(AD_ACCOUNT) catch {
        context.stderr.print("could not fetch meta ad sets\n", .{}) catch
            return CONTEXT.ExitCode.RUNTIME_FAILURE;

        return CONTEXT.ExitCode.RUNTIME_FAILURE;
    };
    defer SCHEMA.freeAdSets(allocator, AD_SETS);

    const ADS = CLIENT.fetchAds(AD_ACCOUNT) catch {
        context.stderr.print("could not fetch meta ads\n", .{}) catch
            return CONTEXT.ExitCode.RUNTIME_FAILURE;

        return CONTEXT.ExitCode.RUNTIME_FAILURE;
    };
    defer SCHEMA.freeAds(allocator, ADS);

    var instagram_accounts: []META.INSTAGRAM_ACCOUNT = &.{};
    defer SCHEMA.freeInstagramAccounts(allocator, instagram_accounts);

    const PAGE_ID = ENV.findEnvVarValue(ENVIRON, &META_ENV.ENV, "page_id", OVERRIDES);

    if (PAGE_ID) |page_id| {
        instagram_accounts = CLIENT.fetchLinkedInstagramAccounts(page_id) catch {
            context.stderr.print(
                "could not fetch linked instagram accounts for the configured page\n",
                .{},
            ) catch return CONTEXT.ExitCode.RUNTIME_FAILURE;

            return CONTEXT.ExitCode.RUNTIME_FAILURE;
        };
    }

    printTree(
        context.stdout,
        ACCOUNT_NAME,
        AD_ACCOUNT,
        PAGES,
        instagram_accounts,
        CAMPAIGNS,
        AD_SETS,
        ADS,
    ) catch {
        context.stderr.print("could not format the meta inventory\n", .{}) catch
            return CONTEXT.ExitCode.RUNTIME_FAILURE;

        return CONTEXT.ExitCode.RUNTIME_FAILURE;
    };

    return CONTEXT.ExitCode.SUCCESS;
}

pub fn printTree(
    writer: *STD.Io.Writer,
    account_name: []const u8,
    ad_account_id: []const u8,
    pages: []const SCHEMA.PAGE,
    instagram: []const META.INSTAGRAM_ACCOUNT,
    campaigns: []const SCHEMA.CAMPAIGN,
    ad_sets: []const SCHEMA.AD_SET,
    ads: []const SCHEMA.AD,
) !void {
    try writer.print("Account: {s} (act_{s})\n", .{ account_name, ad_account_id });

    try printNodeLine(writer, 0, "Pages", .{});

    if (pages.len == 0) {
        try printEmptyLine(writer, 1);
    } else for (pages) |page| {
        try printNodeLine(writer, 1, "{s} [{s}]", .{ page.name, page.id });
    }

    try printNodeLine(writer, 0, "Instagram accounts", .{});

    if (instagram.len == 0) {
        try printEmptyLine(writer, 1);
    } else for (instagram) |account| {
        try printInstagramNodeLine(writer, 1, account);
    }

    try printNodeLine(writer, 0, "Campaigns", .{});

    if (campaigns.len == 0) {
        try printEmptyLine(writer, 1);

        return;
    }

    for (campaigns) |campaign| {
        const OBJECTIVE = if (STD.mem.startsWith(u8, campaign.objective, "OUTCOME_"))
            campaign.objective["OUTCOME_".len..]
        else
            campaign.objective;

        try printNodeLine(
            writer,
            1,
            "{s} [{s}] {s}",
            .{ campaign.name, OBJECTIVE, campaign.status },
        );

        for (ad_sets) |ad_set| {
            if (!STD.mem.eql(u8, ad_set.campaign_id, campaign.id)) continue;

            try printNodeLine(writer, 2, "{s} [{s}]", .{ ad_set.name, ad_set.status });

            for (ads) |ad| {
                if (!STD.mem.eql(u8, ad.ad_set_id, ad_set.id)) continue;

                try printNodeLine(writer, 3, "{s} [{s}]", .{ ad.name, ad.status });
            }
        }
    }
}

fn printNodeLine(
    writer: *STD.Io.Writer,
    depth: usize,
    comptime format: []const u8,
    args: anytype,
) !void {
    try printDepth(writer, depth);
    try writer.writeAll("|- ");
    try writer.print(format, args);
    try writer.writeAll("\n");
}

fn printEmptyLine(
    writer: *STD.Io.Writer,
    depth: usize,
) !void {
    try printDepth(writer, depth);
    try writer.writeAll("- none found\n");
}

fn printInstagramNodeLine(
    writer: *STD.Io.Writer,
    depth: usize,
    account: META.INSTAGRAM_ACCOUNT,
) !void {
    try printDepth(writer, depth);
    try writer.writeAll("|- ");

    if (account.name) |name| {
        try writer.print("{s} ", .{name});
        if (account.username) |username|
            try writer.print("(@{s}) ", .{username});
    } else if (account.username) |username| {
        try writer.print("@{s} ", .{username});
    }

    try writer.print("id={s}", .{account.id});

    if (account.ig_id) |ig_id| {
        if (!STD.mem.eql(u8, ig_id, account.id))
            try writer.print(" ig_id={s}", .{ig_id});
    }

    try writer.writeAll("\n");
}

fn printDepth(
    writer: *STD.Io.Writer,
    depth: usize,
) !void {
    for (0..depth) |_| try writer.writeAll("|  ");
}
