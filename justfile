default:
    @just --list

quarto-preview port="4010":
    @quarto preview --port {{port}}

quarto-render:
    @quarto render

lint args="":
    @treefmt {{ args }} --config-file ./treefmt.lint.toml

format args="":
    @treefmt {{ args }} --config-file ./treefmt.toml
