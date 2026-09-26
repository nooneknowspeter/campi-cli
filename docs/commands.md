# Commands

Commands that change files run in dry run mode by default; use `-w` / `--write`
to persist changes.

- `help` - print the tool and commands help text; `campi-cli help <COMMAND>`
- `version` - print the tool version
- `init` - create the base config file and prepare the working directory;
  the interactive mode is reported as not implemented yet
- `fmt` - format campi files; `-w / --write`, `--lsp`
- `validate` - check the config and manifests for correctness
- `config` - show the active configuration
- `state` - retrieve the current state and compare it against the provided
  state
- `plan` - compare the current manifests against the recorded state and show
  what would change per enabled platform; `--export`
- `apply` - apply the plan and persist state; `-w / --write`, `--exclude <VALUE>`
- `import` - import a hand-created campaign into state:
  `import <PLATFORM> <CAMPAIGN> <EXTERNAL_ID>`; `-w / --write`
- `platform` - fetch and format platform marketing API data;
  `platform <PLATFORM>`; the platform must be one of `meta`, `x`, `tiktok`,
  `google`, `reddit`, `linkedin`

See `campi-cli help <COMMAND>` for the flags of a specific command.
