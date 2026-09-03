# campi-cli

campi-cli will connect to many marketing platforms directly; Meta, TikTok and
such, so you can manage campaigns as code; reviewable, version controlled and
reproducible.

## Build

```sh
zig build
```

## Development

The dev shell provides zig, clang, and the shared treefmt setup:

```sh
just             # list recipes
zig build        # build
just lint        # treefmt lint
just format      # treefmt format
```

To build and install the binary:

```sh
zig build --prefix ~/.local
```

## Roadmap

- [x] project scaffold
  - [x] devshells
  - [x] justfile
  - [x] docs; quarto
  - [x] branding
  - [x] man pages
  - [x] nix
  - [x] ci
- [x] schemas
  - [x] config; the base config file
  - [x] manifest; the campaign manifest
- [ ] cli
  - [x] verbosity; debug logs
  - [x] help command; print tool and commands help text
  - [x] version; print the tool version
  - [ ] init; scaffold a new project
  - [ ] fmt; format manifest files
  - [ ] validate; validate the config and manifests
  - [ ] state; read and compare the state and lock files
  - [ ] config; manage the config file
  - [ ] plan; compute what would change
  - [ ] apply; apply the changes
- [ ] file handling
  - [ ] state reads and compares the state and lock files
  - [ ] plan and apply read the campaign manifest
  - [ ] init writes the base config file and prepares the working directory
- [ ] tests
  - [ ] cli
    - [x] parser
    - [x] runner

## Documentation

- [Installation](docs/installation.md)
- [Usage](docs/usage.md)
- [Commands](docs/commands.md)
- [Development](docs/development.md)

## Project

- [Contributing](CONTRIBUTING.md)
- [Support](SUPPORT.md)
- [Security](SECURITY.md)

## License

See [LICENSE](LICENSE).
