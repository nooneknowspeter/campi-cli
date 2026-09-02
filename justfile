default:
    @just --list

quarto-preview port="4010":
    @quarto preview --port {{port}}

quarto-render:
    @quarto render

quarto-man:
    @quarto render docs/man

lint args="":
    @treefmt {{ args }} --config-file ./treefmt.lint.toml

format args="":
    @treefmt {{ args }} --config-file ./treefmt.toml

# bump and change version specified
bump-version version:
	sed -i 's/\.version = \"[^\"]*\"/.version = \"{{version}}\"/' build.zig.zon
	sed -i '/pname = "campi-cli";/,+1 s/version = "[^"]*"/version = "{{version}}"/' flake.nix
	@echo "bump campi cli to {{version}}"
