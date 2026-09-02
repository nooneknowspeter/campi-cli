const CONTEXT = @import("../context.zig");
const PARSER = @import("../parser.zig");

const GLOBAL_OPTIONS =
    \\
    \\ Global Options:
    \\ -h / --help - Show this help output or the help of a specific command
    \\ -v / --verbose - Show verbose output of a command
    \\ -d <WORK_DIR> / --dir <WORK_DIR> - Run command in the specified working directory
    \\
;

pub const MAIN =
    \\ campi-cli [GLOBAL OPTIONS] <COMMAND> [ARGS]
    \\
    \\ Commands:
    \\ help - print tool and commands help text
    \\ init - create base config file and prepare work dir
    \\ fmt - format campi files
    \\ validate - check campi manifests for correctness
    \\ version - display tool version
    \\ state - retrieve current state and compare against provided state
    \\ plan - fetch and show state data
    \\ apply - apply current manifests and configuration
    \\
++ GLOBAL_OPTIONS;

pub const HELP =
    \\ campi-cli help <COMMAND>
    \\
    \\ Print the help of a specific command
    \\
++ GLOBAL_OPTIONS;

pub const INIT =
    \\ campi-cli [GLOBAL OPTIONS] init [ARGS]
    \\
    \\ Create the base config file and prepare the working directory
    \\
    \\ Args:
    \\ -i / --interactive - Run command in an interactive state; progressive, ask for confirmation
    \\
++ GLOBAL_OPTIONS;

pub const FMT =
    \\ campi-cli [GLOBAL OPTIONS] fmt [ARGS]
    \\
    \\ Format campi files
    \\ runs in dry run mode by default, use -w / --write to persist changes
    \\
    \\ Args:
    \\ -w / --write - Write the reformatted output
    \\ --lsp - Run as a language server
    \\
++ GLOBAL_OPTIONS;

pub const VALIDATE =
    \\ campi-cli [GLOBAL OPTIONS] validate [ARGS]
    \\
    \\ Check the config and manifests for correctness
    \\ runs in dry run mode by default, use -w / --write to persist changes
    \\
    \\ Args:
    \\ -w / --write
    \\
++ GLOBAL_OPTIONS;

pub const VERSION =
    \\ campi-cli [GLOBAL OPTIONS] version [ARGS]
    \\
    \\ Display the tool version
    \\
++ GLOBAL_OPTIONS;

pub const STATE =
    \\ campi-cli [GLOBAL OPTIONS] state [ARGS]
    \\
    \\ Retrieve the current state and compare it against the provided state
    \\
    \\ Args:
    \\ --config-file <PATH/URI>
    \\
++ GLOBAL_OPTIONS;

pub const PLAN =
    \\ campi-cli [GLOBAL OPTIONS] plan [ARGS]
    \\
    \\ Fetch and show state data as a plan
    \\
    \\ Args:
    \\ --export
    \\
++ GLOBAL_OPTIONS;

pub const APPLY =
    \\ campi-cli [GLOBAL OPTIONS] apply [ARGS]
    \\
    \\ Apply the current manifests and configuration
    \\ runs in dry run mode by default, use -w / --write to persist changes
    \\
    \\ Args:
    \\ --exclude <VALUE>
    \\
++ GLOBAL_OPTIONS;

pub fn run(
    context: CONTEXT.CommandContext,
    flags: []const PARSER.ResolvedFlagState,
    flag_values: []const []const u8,
) CONTEXT.ExitCode {
    _ = flags;
    _ = flag_values;

    context.stdout.print("{s}", .{MAIN}) catch
        return CONTEXT.ExitCode.RUNTIME_FAILURE;

    return CONTEXT.ExitCode.SUCCESS;
}
