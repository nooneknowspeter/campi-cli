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

At least one of `CAMPI_META_PAGE_ID` or `CAMPI_META_INSTAGRAM_USER_ID` must be
set; Meta needs a destination when an ad creative is created. `apply -w` fails
before writing anything when neither is set. Blank values count as unset, so
leave the entries you do not use empty. To list the accounts linked to your
page together with their ids:

```
zig build run -- platform meta --dir examples/demo
```
