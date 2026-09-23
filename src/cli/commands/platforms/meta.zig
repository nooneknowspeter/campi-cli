const STD = @import("std");

const CONTEXT = @import("../../context.zig");
const ENV = @import("../../env.zig");
const PARSER = @import("../../parser.zig");
const META_SDK = @import("../../../platforms/meta/main.zig");

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

    if (ENV.findMissingEnvVar(ENVIRON, &META_SDK.ENV)) |missing| {
        context.stderr.print(
            "could not find the {s} environment variable\n",
            .{missing.env_var},
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
