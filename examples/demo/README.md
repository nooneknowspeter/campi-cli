# Demo workspace

A minimal campi-cli workspace. From the repository root:

```
cp examples/demo/.env.example examples/demo/.env
# fill in the Meta credentials in examples/demo/.env
zig build run -- plan --dir examples/demo
zig build run -- apply --dir examples/demo
```

`plan` shows a `+` create for the demo campaign. `apply` is a dry run; add
`-w` / `--write` to create the campaign, ad set, creative, and ad on Meta.
The generated `state.campi` and `.env` are ignored by git.
