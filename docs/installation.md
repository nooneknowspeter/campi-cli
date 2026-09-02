# Installation

## From source

Campaigns as code start with zig 0.16.0 or newer; see the flake dev shell for
the pinned toolchain.

```sh
zig build
```

To build and install the binary under `~/.local`:

```sh
zig build --prefix ~/.local
```

`campi-cli` is then available as `~/.local/bin/campi-cli`.

## Nix

Use campi-cli as a flake input:

```nix
{
  inputs.campi-cli.url = "github:nooneknowspeter/campi-cli";

  outputs = { campi-cli, ... }: {
    # campi-cli.packages.${system}.default is the campi-cli package
  };
}
```

In a checkout of this repository, build, run, and profile install the package:

```sh
nix build .#campi-cli
nix run . -- version
```
