const STD = @import("std");

const CONTEXT = @import("../../context.zig");
const PARSER = @import("../../parser.zig");
const TIKTOK_SDK = @import("../../../platforms/tiktok/main.zig");

pub const FLAGS = [_]PARSER.FlagDefinition{
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
    _ = allocator;
    _ = flags;

    const ENVIRON = context.environ orelse {
        context.stderr.print(
            "could not read the environment\n",
            .{},
        ) catch return CONTEXT.ExitCode.RUNTIME_FAILURE;

        return CONTEXT.ExitCode.RUNTIME_FAILURE;
    };

    if (!TIKTOK_SDK.hasAccessToken(ENVIRON)) {
        context.stderr.print(
            "could not find the {s} environment variable\n",
            .{TIKTOK_SDK.ACCESS_TOKEN_ENV},
        ) catch return CONTEXT.ExitCode.RUNTIME_FAILURE;

        return CONTEXT.ExitCode.RUNTIME_FAILURE;
    }

    context.stderr.print(
        \\{s}
        \\
    , .{CONTEXT.Message.Generic.NOT_IMPLEMENTED}) catch
        return CONTEXT.ExitCode.RUNTIME_FAILURE;

    return CONTEXT.ExitCode.RUNTIME_FAILURE;
}
