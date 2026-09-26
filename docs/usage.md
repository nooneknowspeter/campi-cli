# Usage

`campi-cli` is a command line client for marketing as code.

## Synopsis

```
campi-cli <COMMAND> [ARGS]
```

## Help

Print the main help, or the help of a specific command:

```sh
campi-cli --help
 campi-cli help
 campi-cli help plan
 campi-cli plan --help
 campi-cli help platform
 campi-cli platform meta --help
```

## Shared options

- `-h` / `--help` - show help output for the tool or a specific command
- `-v` / `--verbose` - show verbose output of a command

Some commands also accept a working directory:

- `-d <WORK_DIR>` / `--dir <WORK_DIR>` - run a command in the specified
  working directory

## Dry run

Commands that change files run in dry run mode by default; they report what
would change without touching anything. Pass `-w` / `--write` to persist the
changes. Dry run is the default so that reviewable, version controlled
campaigns stay reproducible.

## Exit codes

- `0` - success
- `1` - runtime failure
- `2` - usage failure
- `3` - pending updates; `plan` / `apply` in dry run computed changes that
  would be applied

## See also

- [Commands](commands.md)
- [Development](development.md)
