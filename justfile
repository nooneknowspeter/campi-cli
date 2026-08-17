default:
    @just --list

quarto-preview:
    @quarto preview

quarto-render:
    @quarto render

lint args="":
    @treefmt {{ args }} --config-file ./treefmt.lint.toml

format args="":
    @treefmt {{ args }} --config-file ./treefmt.toml
