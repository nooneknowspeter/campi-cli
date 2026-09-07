const STD = @import("std");

const BUILD_OPTIONS = @import("build_options");
const CONTEXT = @import("../context.zig");
const PARSER = @import("../parser.zig");

pub fn run(
    allocator: STD.mem.Allocator,
    context: CONTEXT.CommandContext,
    flags: []const PARSER.ResolvedFlagState,
) CONTEXT.ExitCode {
    _ = allocator;
    _ = flags;

    context.stdout.print("{s}\n", .{BUILD_OPTIONS.version_string}) catch
        return CONTEXT.ExitCode.RUNTIME_FAILURE;

    return CONTEXT.ExitCode.SUCCESS;
}
