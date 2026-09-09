# Commands

Every command runs in dry run mode by default; use `-w` / `--write` to persist
changes.

- `help` - print the tool and commands help text; `campi-cli help <COMMAND>`
- `version` - print the tool version
- `init` - create the base config file and prepare the working directory
- `fmt` - format campi files; `-w / --write`, `--lsp`
- `validate` - check the config and manifests for correctness; `-w / --write`
- `state` - retrieve the current state and compare it against the provided
  state
- `plan` - fetch and show state data as a plan; `--export`
- `apply` - apply the current manifests and configuration; `--exclude <VALUE>`

See `campi-cli help <COMMAND>` for the flags of a specific command.
