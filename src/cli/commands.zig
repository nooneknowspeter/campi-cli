const STD = @import("std");

const CONTEXT = @import("context.zig");
const PARSER = @import("parser.zig");

const APPLY = @import("commands/apply.zig");
const FMT = @import("commands/fmt.zig");
pub const HELP = @import("commands/help.zig");
const INIT = @import("commands/init.zig");
const PLAN = @import("commands/plan.zig");
const STATE = @import("commands/state.zig");
const VALIDATE = @import("commands/validate.zig");
const VERSION = @import("commands/version.zig");

pub const CommandHandler = *const fn (
    context: CONTEXT.CommandContext,
    flags: []const PARSER.ResolvedFlagState,
    flag_values: []const []const u8,
) CONTEXT.ExitCode;

pub const CommandDefinition = struct {
    name: []const u8,
    help: []const u8,
    flags: []const PARSER.FlagDefinition,
    run: CommandHandler,
};

pub const NO_FLAGS = [_]PARSER.FlagDefinition{};

pub const COMMAND_REGISTRY = [_]CommandDefinition{
    .{
        .name = "help",
        .help = HELP.HELP,
        .flags = &NO_FLAGS,
        .run = HELP.run,
    },
    .{
        .name = "init",
        .help = HELP.INIT,
        .flags = &INIT.FLAGS,
        .run = INIT.run,
    },
    .{
        .name = "fmt",
        .help = HELP.FMT,
        .flags = &FMT.FLAGS,
        .run = FMT.run,
    },
    .{
        .name = "validate",
        .help = HELP.VALIDATE,
        .flags = &VALIDATE.FLAGS,
        .run = VALIDATE.run,
    },
    .{
        .name = "version",
        .help = HELP.VERSION,
        .flags = &NO_FLAGS,
        .run = VERSION.run,
    },
    .{
        .name = "state",
        .help = HELP.STATE,
        .flags = &STATE.FLAGS,
        .run = STATE.run,
    },
    .{
        .name = "plan",
        .help = HELP.PLAN,
        .flags = &PLAN.FLAGS,
        .run = PLAN.run,
    },
    .{
        .name = "apply",
        .help = HELP.APPLY,
        .flags = &APPLY.FLAGS,
        .run = APPLY.run,
    },
};

pub fn findCommand(name: []const u8) ?*const CommandDefinition {
    for (&COMMAND_REGISTRY) |*definition| {
        if (STD.mem.eql(u8, definition.name, name)) return definition;
    }

    return null;
}
