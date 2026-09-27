const STD = @import("std");

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

    if (ENV.findMissingEnvVar(ENVIRON, &META_ENV.ENV)) |missing| {
        context.stderr.print(
            "could not find the {s} environment variable\n",
            .{missing.env_var},
        ) catch return CONTEXT.ExitCode.RUNTIME_FAILURE;

        return CONTEXT.ExitCode.RUNTIME_FAILURE;
    }

    const TOKEN = ENV.findEnvVarValue(ENVIRON, &META_ENV.ENV, "token").?;
    const AD_ACCOUNT = ENV.findEnvVarValue(ENVIRON, &META_ENV.ENV, "ad_account_id").?;

    const CLIENT = META.Client.init(
        allocator,
        context.io,
        ENV.findEnvVarValue(ENVIRON, &META_ENV.ENV, "graph_api_url").?,
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

    if (CAMPAIGNS.len == 0) {
        context.stdout.print("no campaigns found\n", .{}) catch
            return CONTEXT.ExitCode.RUNTIME_FAILURE;

        return CONTEXT.ExitCode.SUCCESS;
    }

    formatCampaigns(context.stdout, allocator, CAMPAIGNS) catch
        return CONTEXT.ExitCode.RUNTIME_FAILURE;

    return CONTEXT.ExitCode.SUCCESS;
}

pub fn formatCampaigns(
    writer: *STD.Io.Writer,
    allocator: STD.mem.Allocator,
    campaigns: []const META.Campaign,
) !void {
    for (campaigns) |campaign| {
        const DOLLARS = budgetDollars(allocator, campaign.daily_budget) catch continue;
        defer allocator.free(DOLLARS);

        const OBJECTIVE = if (STD.mem.startsWith(u8, campaign.objective, "OUTCOME_"))
            campaign.objective["OUTCOME_".len..]
        else
            campaign.objective;

        try writer.print(
            "{s} [{s}] {s} {s}\n",
            .{
                campaign.name,
                OBJECTIVE,
                campaign.status,
                DOLLARS,
            },
        );
    }
}

fn budgetDollars(allocator: STD.mem.Allocator, cents: []const u8) ![]const u8 {
    const VALUE = try STD.fmt.parseInt(u64, cents, 10);
    return STD.fmt.allocPrint(allocator, "${d}.{d:0>2}", .{ VALUE / 100, VALUE % 100 });
}
