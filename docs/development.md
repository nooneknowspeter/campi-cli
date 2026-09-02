# Development

## Dev shell

The flake provides a nix dev shell with zig, clang, quarto, and the shared
treefmt setup:

```sh
nix develop
```

## Quick commands

The justfile holds the common recipes:

- `just` - list recipes
- `zig build` - build the binary
- `zig build test` - run the test suite
- `just lint` - treefmt lint
- `just format` - treefmt format
- `just quarto-render` - render the docs website into `_output/`
- `just quarto-man` - render the man page into `_output/docs/man/`
- `just quarto-preview` - preview the website locally

## Docs

Root markdown files are rendered into the quarto website; see the `render` and
`sidebar` sections of `_quarto.yaml`. Man page source lives in `docs/man/`.

## Testing

The test suites live next to the code they cover in `src/`. Run everything
with:

```sh
zig build test
```
