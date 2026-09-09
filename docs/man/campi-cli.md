% CAMPI-CLI(1) campi-cli 0.0.0
% campi-cli
% 2026

# NAME

campi-cli - command line client for marketing as code

# SYNOPSIS

`campi-cli <COMMAND> [ARGS]`

# DESCRIPTION

campi-cli manages campaigns as code; reviewable, version controlled and
reproducible. It will connect to many marketing platforms directly; Meta,
TikTok and such.

Commands that change files run in dry run mode by default; they report what
would change without touching anything. Pass `-w` / `--write` to persist the
changes.

# SHARED OPTIONS

`-h`, `--help`
: Show help output for the tool or a specific command.

`-v`, `--verbose`
: Show verbose output of a command.

Some commands also accept a working directory:

`-d <WORK_DIR>`, `--dir <WORK_DIR>`
: Run a command in the specified working directory.

# COMMANDS

`help`
: Print the tool and commands help text; `campi-cli help <COMMAND>`.

`version`
: Print the tool version.

`init`
: Create the base config file and prepare the working directory; on an
existing config, reports the directory as already initialized.

`fmt`
: Format campi files; `-w` / `--write`, `--lsp`.

`validate`
: Check the config and manifests for correctness; `-w` / `--write`.

`state`
: Retrieve the current state and compare it against the provided state;
`--dir <WORK_DIR>`.

`plan`
: Fetch and show state data as a plan; `--export`.

`apply`
: Apply the current manifests and configuration; `--exclude <VALUE>`.

# EXIT CODES

`0`
: Success.

`1`
: Runtime failure.

`2`
: Usage failure.

`3`
: Pending updates: `fmt` in dry run would reformat at least one file.

# FILES

`config.campi.zon`
: The base config file; created and loaded by `campi-cli init`.

`example.manifest.campi.zon`
: Example campaign manifest; scaffolded by `campi-cli init`, read by `campi-cli plan` and `campi-cli apply`.

`state.campi.zon`
: The state file; read by `campi-cli state`. Its location is set by
`state_file_location_type` and `state_file_uri` in `config.campi.zon`:
`.local` (default) stores it in the working directory, `.cloud` points at a
remote backend URI (`s3://<bucket>/<key>` or `gdrive://<root>/<path>`; not
implemented yet).

# SEE ALSO

The campi-cli source and documentation live in the repository
`github:nooneknowspeter/campi-cli`.
