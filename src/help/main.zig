const GLOBAL_OPTIONS =
    \\
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
    \\ init - create base config file and prepare work dir
    \\ fmt - format campi files
    \\ version - display tool version
    \\ state - retrieve current state and compare against provided state
    \\ config - show config information
    \\ plan - fetch and show state data
    \\ apply - apply current manifests and configuration
++ GLOBAL_OPTIONS;

pub const INIT =
    \\ campi-cli [GLOBAL OPTIONS] init [ARGS]
    \\
    \\ Args:
    \\ -i / --interactive - Run command in an interactive state; progressive, ask for confirmation
++ GLOBAL_OPTIONS;

pub const FMT =
    \\ campi-cli [GLOBAL OPTIONS] fmt [ARGS]
    \\
    \\ Args:
    \\ -w / --write
    \\ --lsp
++ GLOBAL_OPTIONS;

pub const VERSION =
    \\ campi-cli [GLOBAL OPTIONS] version [ARGS]
++ GLOBAL_OPTIONS;

pub const STATE =
    \\ campi-cli [GLOBAL OPTIONS] state [ARGS]
    \\
    \\ Args:
    \\ --config-file <PATH/URI>
++ GLOBAL_OPTIONS;

pub const CONFIG =
    \\ campi-cli [GLOBAL OPTIONS] config [ARGS]
    \\
    \\ Args:
    \\ --validate
++ GLOBAL_OPTIONS;

pub const PLAN =
    \\ campi-cli [GLOBAL OPTIONS] plan [ARGS]
    \\
    \\ Args:
    \\ --export
++ GLOBAL_OPTIONS;

pub const APPLY =
    \\ campi-cli [GLOBAL OPTIONS] apply [ARGS]
    \\
    \\ Args:
    \\ --exclude <VALUE>
++ GLOBAL_OPTIONS;
