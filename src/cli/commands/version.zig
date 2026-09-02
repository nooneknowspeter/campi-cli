const BUILD_OPTIONS = @import("build_options");
const CONTEXT = @import("../context.zig");
const PARSER = @import("../parser.zig");

pub fn run(
    context: CONTEXT.CommandContext,
    flags: []const PARSER.ResolvedFlagState,
    flag_values: []const []const u8,
) CONTEXT.ExitCode {
    _ = flags;
    _ = flag_values;

    context.stdout.print("{s}\n", .{BUILD_OPTIONS.version_string}) catch
        return CONTEXT.ExitCode.RUNTIME_FAILURE;

    return CONTEXT.ExitCode.SUCCESS;
}
