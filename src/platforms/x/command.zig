const STD = @import("std");

const CONTEXT = @import("../../cli/context.zig");
const PARSER = @import("../../cli/parser.zig");

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
    , .{CONTEXT.Message.Generic.NOT_IMPLEMENTED}) catch
        return CONTEXT.ExitCode.RUNTIME_FAILURE;

    return CONTEXT.ExitCode.RUNTIME_FAILURE;
}
