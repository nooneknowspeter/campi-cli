const STD = @import("std");

const CONTEXT = @import("context.zig");
const PARSER = @import("parser.zig");

const APPLY = @import("commands/apply.zig");
const FMT = @import("commands/fmt.zig");
pub const HELP = @import("commands/help.zig");
const IMPORT = @import("commands/import.zig");
const INIT = @import("commands/init.zig");
const PLAN = @import("commands/plan.zig");
const STATE = @import("commands/state.zig");
const VALIDATE = @import("commands/validate.zig");
const VERSION = @import("commands/version.zig");

pub const CommandHandler = *const fn (
    allocator: STD.mem.Allocator,
    context: CONTEXT.CommandContext,
    flags: []const PARSER.ResolvedFlagState,
) CONTEXT.ExitCode;

pub const CommandDefinition = struct {
    name: []const u8,
    help: []const u8,
    flags: []const PARSER.FlagDefinition,
    run: CommandHandler,
};

const NO_FLAGS = [_]PARSER.FlagDefinition{};

const SHARED_FLAGS = [_]PARSER.FlagDefinition{
    .{
        .long_flag = "help",
        .short_flag = 'h',
        .is_flag_a_boolean = true,
        .description = "Show help output",
    },
    .{
        .long_flag = "verbose",
        .short_flag = 'v',
        .is_flag_a_boolean = true,
        .description = "Show verbose output",
    },
};

// comptime merging
const INIT_FLAGS = SHARED_FLAGS ++ INIT.FLAGS;
const FMT_FLAGS = SHARED_FLAGS ++ FMT.FLAGS;
const VALIDATE_FLAGS = SHARED_FLAGS ++ VALIDATE.FLAGS;
const STATE_FLAGS = SHARED_FLAGS ++ STATE.FLAGS;
const PLAN_FLAGS = SHARED_FLAGS ++ PLAN.FLAGS;
const APPLY_FLAGS = SHARED_FLAGS ++ APPLY.FLAGS;
const IMPORT_FLAGS = SHARED_FLAGS ++ IMPORT.FLAGS;

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
        .flags = &INIT_FLAGS,
        .run = INIT.run,
    },
    .{
        .name = "fmt",
        .help = HELP.FMT,
        .flags = &FMT_FLAGS,
        .run = FMT.run,
    },
    .{
        .name = "validate",
        .help = HELP.VALIDATE,
        .flags = &VALIDATE_FLAGS,
        .run = VALIDATE.run,
    },
    .{
        .name = "version",
        .help = HELP.VERSION,
        .flags = &SHARED_FLAGS,
        .run = VERSION.run,
    },
    .{
        .name = "state",
        .help = HELP.STATE,
        .flags = &STATE_FLAGS,
        .run = STATE.run,
    },
    .{
        .name = "plan",
        .help = HELP.PLAN,
        .flags = &PLAN_FLAGS,
        .run = PLAN.run,
    },
    .{
        .name = "apply",
        .help = HELP.APPLY,
        .flags = &APPLY_FLAGS,
        .run = APPLY.run,
    },
    .{
        .name = "import",
        .help = HELP.IMPORT,
        .flags = &IMPORT_FLAGS,
        .run = IMPORT.run,
    },
};

pub fn findCommand(name: []const u8) ?*const CommandDefinition {
    for (&COMMAND_REGISTRY) |*definition| {
        if (STD.mem.eql(u8, definition.name, name)) return definition;
    }

    return null;
}
