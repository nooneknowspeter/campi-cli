const CONTEXT = @import("../context.zig");
const PARSER = @import("../parser.zig");

pub const MAIN =
    \\ campi-cli <COMMAND> [ARGS]
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
;

pub const HELP =
    \\ campi-cli help <COMMAND>
    \\
    \\ Print the help of a specific command
    \\
    \\ Args:
    \\ -h / --help - Show this help output
    \\ -v / --verbose - Show verbose output and debug logs
    \\
;

pub const INIT =
    \\ campi-cli init [ARGS]
    \\
    \\ Create the base config file and prepare the working directory
    \\
    \\ Args:
    \\ -h / --help - Show this help output
    \\ -v / --verbose - Show verbose output and debug logs
    \\ -i / --interactive - Run command in an interactive state; progressive, ask for confirmation
    \\ -d <WORK_DIR> / --dir <WORK_DIR> - Run command in the specified working directory
    \\
;

pub const FMT =
    \\ campi-cli fmt [ARGS]
    \\
    \\ Format campi files
    \\ runs in dry run mode by default, use -w / --write to persist changes
    \\
    \\ Args:
    \\ -h / --help - Show this help output
    \\ -v / --verbose - Show verbose output and debug logs
    \\ -w / --write - Write the reformatted output
    \\ --lsp - Run as a language server
    \\ -d <WORK_DIR> / --dir <WORK_DIR> - Run command in the specified working directory
    \\
;

pub const VALIDATE =
    \\ campi-cli validate [ARGS]
    \\
    \\ Check the config and manifests for correctness
    \\ runs in dry run mode by default, use -w / --write to persist changes
    \\
    \\ Args:
    \\ -h / --help - Show this help output
    \\ -v / --verbose - Show verbose output and debug logs
    \\ -w / --write
    \\ -d <WORK_DIR> / --dir <WORK_DIR> - Run command in the specified working directory
    \\
;

pub const VERSION =
    \\ campi-cli version [ARGS]
    \\
    \\ Display the tool version
    \\
    \\ Args:
    \\ -h / --help - Show this help output
    \\ -v / --verbose - Show verbose output and debug logs
    \\
;

pub const STATE =
    \\ campi-cli state [ARGS]
    \\
    \\ Retrieve the current state and compare it against the provided state
    \\
    \\ Args:
    \\ -h / --help - Show this help output
    \\ -v / --verbose - Show verbose output and debug logs
    \\ --config-file <PATH/URI>
    \\ -d <WORK_DIR> / --dir <WORK_DIR> - Run command in the specified working directory
    \\
;

pub const PLAN =
    \\ campi-cli plan [ARGS]
    \\
    \\ Fetch and show state data as a plan
    \\
    \\ Args:
    \\ -h / --help - Show this help output
    \\ -v / --verbose - Show verbose output and debug logs
    \\ --export
    \\ -d <WORK_DIR> / --dir <WORK_DIR> - Run command in the specified working directory
    \\
;

pub const APPLY =
    \\ campi-cli apply [ARGS]
    \\
    \\ Apply the current manifests and configuration
    \\ runs in dry run mode by default, use -w / --write to persist changes
    \\
    \\ Args:
    \\ -h / --help - Show this help output
    \\ -v / --verbose - Show verbose output and debug logs
    \\ --exclude <VALUE>
    \\ -d <WORK_DIR> / --dir <WORK_DIR> - Run command in the specified working directory
    \\
;

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
