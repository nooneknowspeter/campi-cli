const CONTEXT = @import("../context.zig");
const PARSER = @import("../parser.zig");

pub const FLAGS = [_]PARSER.FlagDefinition{
    .{
        .long_flag = "write",
        .short_flag = 'w',
        .is_flag_a_boolean = true,
        .description = "Write fixes",
    },
};

pub fn run(
    context: CONTEXT.CommandContext,
    flags: []const PARSER.ResolvedFlagState,
    flag_values: []const []const u8,
) CONTEXT.ExitCode {
    _ = flags;
    _ = flag_values;

    context.stderr.print("validate: not implemented yet\n", .{}) catch
        return CONTEXT.ExitCode.RUNTIME_FAILURE;

    return CONTEXT.ExitCode.RUNTIME_FAILURE;
}
