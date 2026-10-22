const STD = @import("std");

const CONFIG = @import("../../config/main.zig");
const CONTEXT = @import("../../cli/context.zig");
const ENV = @import("../../cli/env.zig");
const GOOGLE = @import("main.zig");
const GOOGLE_ENV = @import("env.zig");
const PARSER = @import("../../cli/parser.zig");
const SCHEMA = @import("schema.zig");
const TREE = @import("../../render/tree.zig");

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
            CONFIGURATION.platform_configs.google
        else
            null,
    ) catch {
        context.stderr.print(
            "could not build the environment variable overrides\n",
            .{},
        ) catch return CONTEXT.ExitCode.RUNTIME_FAILURE;

        return CONTEXT.ExitCode.RUNTIME_FAILURE;
    };
    defer if (OVERRIDES) |overrides| allocator.free(overrides);

    if (ENV.findMissingEnvVar(ENVIRON, &GOOGLE_ENV.ENV, OVERRIDES)) |missing| {
        context.stderr.print(
            "could not find the {s} environment variable\n",
            .{ENV.effectiveEnvVar(&GOOGLE_ENV.ENV, missing.key, OVERRIDES)},
        ) catch return CONTEXT.ExitCode.RUNTIME_FAILURE;

        return CONTEXT.ExitCode.RUNTIME_FAILURE;
    }

    const DEVELOPER_TOKEN = ENV.findEnvVarValue(
        ENVIRON,
        &GOOGLE_ENV.ENV,
        "developer_token",
        OVERRIDES,
    ).?;
    const CLIENT_ID = ENV.findEnvVarValue(
        ENVIRON,
        &GOOGLE_ENV.ENV,
        "client_id",
        OVERRIDES,
    ).?;
    const CLIENT_SECRET = ENV.findEnvVarValue(
        ENVIRON,
        &GOOGLE_ENV.ENV,
        "client_secret",
        OVERRIDES,
    ).?;
    const REFRESH_TOKEN = ENV.findEnvVarValue(
        ENVIRON,
        &GOOGLE_ENV.ENV,
        "refresh_token",
        OVERRIDES,
    ).?;
    const CUSTOMER_ID = GOOGLE.normalizeCustomerId(
        allocator,
        ENV.findEnvVarValue(
            ENVIRON,
            &GOOGLE_ENV.ENV,
            "customer_id",
            OVERRIDES,
        ).?,
    ) catch {
        context.stderr.print(
            "could not read the google ads customer id\n",
            .{},
        ) catch return CONTEXT.ExitCode.RUNTIME_FAILURE;

        return CONTEXT.ExitCode.RUNTIME_FAILURE;
    };
    defer allocator.free(CUSTOMER_ID);

    const TOKEN_PARAMETERS = GOOGLE.TokenParameters{
        .token_url = ENV.findEnvVarValue(
            ENVIRON,
            &GOOGLE_ENV.ENV,
            "token_url",
            OVERRIDES,
        ).?,
        .client_id = CLIENT_ID,
        .client_secret = CLIENT_SECRET,
        .refresh_token = REFRESH_TOKEN,
    };

    const ACCESS_TOKEN = GOOGLE.fetchAccessToken(
        allocator,
        context.io,
        &TOKEN_PARAMETERS,
    ) catch {
        context.stderr.print(
            "could not exchange the google ads refresh token\n",
            .{},
        ) catch return CONTEXT.ExitCode.RUNTIME_FAILURE;

        return CONTEXT.ExitCode.RUNTIME_FAILURE;
    };
    defer allocator.free(ACCESS_TOKEN);

    const CLIENT_PARAMETERS = GOOGLE.ClientParameters{
        .api_url = ENV.findEnvVarValue(
            ENVIRON,
            &GOOGLE_ENV.ENV,
            "api_url",
            OVERRIDES,
        ).?,
        .developer_token = DEVELOPER_TOKEN,
        .customer_id = CUSTOMER_ID,
        .login_customer_id = ENV.findEnvVarValue(
            ENVIRON,
            &GOOGLE_ENV.ENV,
            "login_customer_id",
            OVERRIDES,
        ),
        .access_token = ACCESS_TOKEN,
    };

    const CLIENT = GOOGLE.Client.init(
        allocator,
        context.io,
        &CLIENT_PARAMETERS,
    );

    const ACCOUNT = CLIENT.fetchAccount() catch {
        context.stderr.print("could not fetch the google ads account\n", .{}) catch
            return CONTEXT.ExitCode.RUNTIME_FAILURE;

        return CONTEXT.ExitCode.RUNTIME_FAILURE;
    };
    defer {
        if (ACCOUNT) |account| SCHEMA.freeAccount(allocator, account);
    }

    const CAMPAIGNS = CLIENT.fetchCampaigns() catch {
        context.stderr.print("could not fetch google ads campaigns\n", .{}) catch
            return CONTEXT.ExitCode.RUNTIME_FAILURE;

        return CONTEXT.ExitCode.RUNTIME_FAILURE;
    };
    defer SCHEMA.freeCampaigns(allocator, CAMPAIGNS);

    const AD_GROUPS = CLIENT.fetchAdGroups() catch {
        context.stderr.print("could not fetch google ads ad groups\n", .{}) catch
            return CONTEXT.ExitCode.RUNTIME_FAILURE;

        return CONTEXT.ExitCode.RUNTIME_FAILURE;
    };
    defer SCHEMA.freeAdGroups(allocator, AD_GROUPS);

    const ADS = CLIENT.fetchAds() catch {
        context.stderr.print("could not fetch google ads ads\n", .{}) catch
            return CONTEXT.ExitCode.RUNTIME_FAILURE;

        return CONTEXT.ExitCode.RUNTIME_FAILURE;
    };
    defer SCHEMA.freeAds(allocator, ADS);

    const ACCOUNT_NAME = if (ACCOUNT) |account| account.name else "";
    const ACCOUNT_ID = if (ACCOUNT) |account| account.id else "";

    printTree(
        context.stdout,
        ACCOUNT_NAME,
        if (ACCOUNT_ID.len == 0) CUSTOMER_ID else ACCOUNT_ID,
        CAMPAIGNS,
        AD_GROUPS,
        ADS,
    ) catch {
        context.stderr.print("could not format the google ads inventory\n", .{}) catch
            return CONTEXT.ExitCode.RUNTIME_FAILURE;

        return CONTEXT.ExitCode.RUNTIME_FAILURE;
    };

    return CONTEXT.ExitCode.SUCCESS;
}

pub fn printTree(
    writer: *STD.Io.Writer,
    account_name: []const u8,
    customer_id: []const u8,
    campaigns: []const SCHEMA.CAMPAIGN,
    ad_groups: []const SCHEMA.AD_GROUP,
    ads: []const SCHEMA.AD,
) !void {
    try writer.print(
        "Account: {s} ({s})\n",
        .{
            if (account_name.len == 0) "Unknown" else account_name,
            customer_id,
        },
    );

    try TREE.printNodeLine(writer, 0, "Campaigns", .{});

    if (campaigns.len == 0) {
        try TREE.printEmptyLine(writer, 1);

        return;
    }

    for (campaigns) |campaign| {
        try TREE.printNodeLine(
            writer,
            1,
            "{s} [{s}] {s}",
            .{ campaign.name, campaign.channel_type, campaign.status },
        );

        for (ad_groups) |ad_group| {
            if (!STD.mem.eql(u8, ad_group.campaign_id, campaign.id)) continue;

            try TREE.printNodeLine(
                writer,
                2,
                "{s} [{s}]",
                .{ ad_group.name, ad_group.status },
            );

            for (ads) |ad| {
                if (!STD.mem.eql(u8, ad.ad_group_id, ad_group.id)) continue;

                const LABEL = if (ad.name.len > 0)
                    ad.name
                else if (ad.ad_type.len > 0)
                    ad.ad_type
                else
                    ad.id;

                try TREE.printNodeLine(
                    writer,
                    3,
                    "{s} [{s}]",
                    .{ LABEL, ad.status },
                );
            }
        }
    }
}
