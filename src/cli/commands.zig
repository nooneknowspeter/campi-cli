const STD = @import("std");

const CONTEXT = @import("context.zig");
const PARSER = @import("parser.zig");

const APPLY_CMD = @import("commands/apply.zig");
const CONFIG_CMD = @import("commands/config.zig");
const FMT_CMD = @import("commands/fmt.zig");
pub const HELP = @import("commands/help.zig");
const GOOGLE_CMD = @import("commands/platforms/google.zig");
const IMPORT_CMD = @import("commands/import.zig");
const INIT_CMD = @import("commands/init.zig");
const LINKEDIN_CMD = @import("commands/platforms/linkedin.zig");
const META_CMD = @import("commands/platforms/meta.zig");
const PLAN_CMD = @import("commands/plan.zig");
const REDDIT_CMD = @import("commands/platforms/reddit.zig");
const STATE_CMD = @import("commands/state.zig");
const TIKTOK_CMD = @import("commands/platforms/tiktok.zig");
const VALIDATE_CMD = @import("commands/validate.zig");
const VERSION_CMD = @import("commands/version.zig");
const X_CMD = @import("commands/platforms/x.zig");

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
const INIT_FLAGS = SHARED_FLAGS ++ INIT_CMD.FLAGS;
const FMT_FLAGS = SHARED_FLAGS ++ FMT_CMD.FLAGS;
const VALIDATE_FLAGS = SHARED_FLAGS ++ VALIDATE_CMD.FLAGS;
const CONFIG_FLAGS = SHARED_FLAGS ++ CONFIG_CMD.FLAGS;
const STATE_FLAGS = SHARED_FLAGS ++ STATE_CMD.FLAGS;
const PLAN_FLAGS = SHARED_FLAGS ++ PLAN_CMD.FLAGS;
const APPLY_FLAGS = SHARED_FLAGS ++ APPLY_CMD.FLAGS;
const IMPORT_FLAGS = SHARED_FLAGS ++ IMPORT_CMD.FLAGS;
const META_FLAGS = SHARED_FLAGS ++ META_CMD.FLAGS;
const TIKTOK_FLAGS = SHARED_FLAGS ++ TIKTOK_CMD.FLAGS;
const X_FLAGS = SHARED_FLAGS ++ X_CMD.FLAGS;
const GOOGLE_FLAGS = SHARED_FLAGS ++ GOOGLE_CMD.FLAGS;
const REDDIT_FLAGS = SHARED_FLAGS ++ REDDIT_CMD.FLAGS;
const LINKEDIN_FLAGS = SHARED_FLAGS ++ LINKEDIN_CMD.FLAGS;

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
        .run = INIT_CMD.run,
    },
    .{
        .name = "fmt",
        .help = HELP.FMT,
        .flags = &FMT_FLAGS,
        .run = FMT_CMD.run,
    },
    .{
        .name = "validate",
        .help = HELP.VALIDATE,
        .flags = &VALIDATE_FLAGS,
        .run = VALIDATE_CMD.run,
    },
    .{
        .name = "config",
        .help = HELP.CONFIG,
        .flags = &CONFIG_FLAGS,
        .run = CONFIG_CMD.run,
    },
    .{
        .name = "version",
        .help = HELP.VERSION,
        .flags = &SHARED_FLAGS,
        .run = VERSION_CMD.run,
    },
    .{
        .name = "state",
        .help = HELP.STATE,
        .flags = &STATE_FLAGS,
        .run = STATE_CMD.run,
    },
    .{
        .name = "plan",
        .help = HELP.PLAN,
        .flags = &PLAN_FLAGS,
        .run = PLAN_CMD.run,
    },
    .{
        .name = "apply",
        .help = HELP.APPLY,
        .flags = &APPLY_FLAGS,
        .run = APPLY_CMD.run,
    },
    .{
        .name = "import",
        .help = HELP.IMPORT,
        .flags = &IMPORT_FLAGS,
        .run = IMPORT_CMD.run,
    },
    .{
        .name = "meta",
        .help = HELP.META,
        .flags = &META_FLAGS,
        .run = META_CMD.run,
    },
    .{
        .name = "tiktok",
        .help = HELP.TIKTOK,
        .flags = &TIKTOK_FLAGS,
        .run = TIKTOK_CMD.run,
    },
    .{
        .name = "x",
        .help = HELP.X,
        .flags = &X_FLAGS,
        .run = X_CMD.run,
    },
    .{
        .name = "google",
        .help = HELP.GOOGLE,
        .flags = &GOOGLE_FLAGS,
        .run = GOOGLE_CMD.run,
    },
    .{
        .name = "reddit",
        .help = HELP.REDDIT,
        .flags = &REDDIT_FLAGS,
        .run = REDDIT_CMD.run,
    },
    .{
        .name = "linkedin",
        .help = HELP.LINKEDIN,
        .flags = &LINKEDIN_FLAGS,
        .run = LINKEDIN_CMD.run,
    },
};

pub fn findCommand(name: []const u8) ?*const CommandDefinition {
    for (&COMMAND_REGISTRY) |*definition| {
        if (STD.mem.eql(u8, definition.name, name)) return definition;
    }

    return null;
}
