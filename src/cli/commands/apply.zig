const CONTEXT = @import("../context.zig");
const PARSER = @import("../parser.zig");

pub const FLAGS = [_]PARSER.FlagDefinition{
    .{
        .long_flag = "exclude",
        .short_flag = null,
        .is_flag_a_boolean = false,
        .description = "Exclude a value from the apply",
    },
};

pub fn run(
    context: CONTEXT.CommandContext,
    flags: []const PARSER.ResolvedFlagState,
    flag_values: []const []const u8,
) CONTEXT.ExitCode {
    _ = flags;
    _ = flag_values;

    context.stderr.print("apply: not implemented yet\n", .{}) catch
        return CONTEXT.ExitCode.RUNTIME_FAILURE;

    return CONTEXT.ExitCode.RUNTIME_FAILURE;
}
