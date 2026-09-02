const CONTEXT = @import("../context.zig");
const PARSER = @import("../parser.zig");

pub const FLAGS = [_]PARSER.FlagDefinition{
    .{
        .long_flag = "export",
        .short_flag = null,
        .is_flag_a_boolean = true,
        .description = "Export the plan",
    },
};

pub fn run(
    context: CONTEXT.CommandContext,
    flags: []const PARSER.ResolvedFlagState,
    flag_values: []const []const u8,
) CONTEXT.ExitCode {
    _ = flags;
    _ = flag_values;

    context.stderr.print("plan: not implemented yet\n", .{}) catch
        return CONTEXT.ExitCode.RUNTIME_FAILURE;

    return CONTEXT.ExitCode.RUNTIME_FAILURE;
}
