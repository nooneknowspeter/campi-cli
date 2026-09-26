const STD = @import("std");

const CONTEXT = @import("../../cli/context.zig");
const ENV = @import("../../cli/env.zig");
const PARSER = @import("../../cli/parser.zig");
const SDK = @import("main.zig");

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

    if (ENV.findMissingEnvVar(ENVIRON, &SDK.ENV)) |missing| {
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
