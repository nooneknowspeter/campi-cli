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
: Create the base config file and prepare the working directory,
scaffolding `config.campi`, `example.manifest.campi` and `.env.example`; on
an existing config, reports the directory as already initialized. The
interactive mode is reported as not implemented yet.

`fmt`
: Format campi files; `-w` / `--write`, `--lsp`.

`validate`
: Check the config and manifests for correctness.

`config`
: Show the active configuration: the config file location, config and campi
versions, project name, state file location, enabled platforms, and configured
manifest files.

`state`
: Retrieve the current state and compare it against the provided state;
`--dir <WORK_DIR>`.

`plan`
: Compute what would change by comparing the current campaign manifests
against the recorded state, one section per enabled platform; `+` creates,
`~` updates, `-` archives. `--export` prints the plan as ZON. Exits `3` when
changes are pending, `0` otherwise.

`apply`
: Apply the plan from the current manifests; dry run by default. `-w` /
`--write` takes a write lock on `state.campi.lock` and persists the changes
to `state.campi`. `--exclude <VALUE>` skips a campaign by name. Exits `3` in
dry run when changes would be applied, `0` otherwise.

`import`
: Import a hand-created campaign into state;
`campi-cli import <PLATFORM> <CAMPAIGN> <EXTERNAL_ID>`. Takes a write lock
on `state.campi.lock` and appends the record; the platform must be one of
`meta`, `x`, `tiktok`, `google`, `reddit`, `linkedin`.

`platform`
: Fetch and format platform marketing API data;
`campi-cli platform <PLATFORM>`. The platform must be one of `meta`, `x`,
`tiktok`, `google`, `reddit`, `linkedin`; the `meta` platform covers
Facebook, Instagram, Messenger and other Meta destinations through the
Marketing API. `campi-cli platform meta` lists the ad account's campaigns
with their objective and status. Data fetching is implemented
for `meta`; the remaining platforms are reported as not implemented yet.

# ENVIRONMENT

A file named `.env` in the working directory is loaded into the current
session on every command. Values from the file take precedence over
environment variables already set in the current session. Lines are
`KEY=VALUE`; blank lines and lines starting with `#` are ignored, and a value
wrapped in double quotes has the quotes removed.

Platform credentials are read from the environment:

`CAMPI_META_ACCESS_TOKEN`
: Meta (Facebook) user access token for the marketing API; long lived and
granted the `ads_management` permission.

`CAMPI_META_AD_ACCOUNT`
: Meta ad account id, in the form `act_<id>`.

`CAMPI_META_PAGE_ID`
: Optional; Meta page id used to publish ad creatives to a Facebook page.
One of this or `CAMPI_META_INSTAGRAM_ACTOR_ID` is required to write ad
creatives.

`CAMPI_META_INSTAGRAM_ACTOR_ID`
: Optional; Instagram business account id used to publish ad creatives to
Instagram; the account must be linked to the ad account in Business Manager.
One of this or `CAMPI_META_PAGE_ID` is required to write ad creatives.

`CAMPI_META_GRAPH_API_URL`
: Meta Graph API base URL; defaults to `https://graph.facebook.com/v26.0`.

`CAMPI_TIKTOK_ACCESS_TOKEN`
: TikTok marketing API access token.

Per platform, `config.campi` can override the variable names under
`platform_configs`; a field is named after the key above with the `_env`
suffix. For `meta`: `token_env`, `ad_account_id_env`, `page_id_env`,
`instagram_actor_id_env`, `graph_api_url_env`. For `tiktok`: `token_env`. The
field value is the environment variable used for that key instead of the
default `CAMPI_...` one above.

# EXIT CODES

`0`
: Success.

`1`
: Runtime failure.

`2`
: Usage failure.

`3`
: Pending updates: `fmt` in dry run would reformat at least one file, or
`plan` / `apply` in dry run computed changes that would be applied.

# FILES

`config.campi`
: The base config file; created and loaded by `campi-cli init`.

`example.manifest.campi`
: Example campaign manifest; scaffolded by `campi-cli init`, read by `campi-cli plan` and `campi-cli apply`.

`.env.example`
: Template credentials file scaffolded by `campi-cli init`; copy it to `.env`
and fill in the real values.

`.env`
: Optional file of `KEY=VALUE` credential lines, loaded into the session with
precedence over the current environment; ignored by `git` by default.

`state.campi`
: The state file; read by `campi-cli state`, `plan` and `apply`, written by
`apply -w` and `import`. Its location is set by `state_file_location_type`
and `state_file_uri` in `config.campi`: `.local` (default) stores it in the
working directory, `.cloud` points at a remote backend URI
(`s3://<bucket>/<key>` or `gdrive://<root>/<path>`; not implemented yet).

`state.campi.lock`
: Write lock file; taken by `apply -w` and `import` while writing state.

# SEE ALSO

The campi-cli source and documentation live in the repository
`github:nooneknowspeter/campi-cli`.
