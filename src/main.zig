const STD = @import("std");

const CLI = @import("cli/main.zig");
const CONTEXT = @import("cli/context.zig");
const ARTIFACTS = @import("artifacts/main.zig");

pub const std_options: STD.Options = .{
    .log_level = .debug,
    .logFn = customLogFn,
};

fn customLogFn(
    comptime level: STD.log.Level,
    comptime scope: @EnumLiteral(),
    comptime format: []const u8,
    args: anytype,
) void {
    if (level == .debug and !CONTEXT.verbose) return;

    STD.log.defaultLog(level, scope, format, args);
}

pub fn main(init: STD.process.Init) u8 {
    return CLI.main(init);
}

test {
    _ = @import("cli/main.zig");
    _ = ARTIFACTS;
    _ = @import("cli/env.zig");
    _ = @import("platforms/meta/main.zig");
    _ = @import("platforms/meta/payload.zig");
}
