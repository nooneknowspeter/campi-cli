const STD = @import("std");

const CONTEXT = @import("../context.zig");
const PARSER = @import("../parser.zig");

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

    context.stderr.print(
        \\{s}
        \\
    , .{CONTEXT.Message.NOT_IMPLEMENTED}) catch
        return CONTEXT.ExitCode.RUNTIME_FAILURE;

    return CONTEXT.ExitCode.RUNTIME_FAILURE;
}