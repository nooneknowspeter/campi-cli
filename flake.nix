{
  description = "campi-cli";

  inputs = {
    excalidraw-edit = {
      url = "github:wh1le/excalidraw-edit";
    };

    flake-utils = {
      url = "github:numtide/flake-utils";
    };

    nixpkgs = {
      url = "github:nixos/nixpkgs/nixpkgs-unstable";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;

          config = {
            allowUnfree = true;
          };
        };

        runtime_pkgs = with pkgs; [
          # runtimes & compilers
          clang
          zig
        ];

        dev_pkgs = with pkgs; [
          # dev tools
          act
          direnv
          git
          just
          opencode
        ];

        campi_cli = pkgs.stdenv.mkDerivation {
          pname = "campi-cli";
          version = "0.0.0";
          src = self;
          nativeBuildInputs = [
            pkgs.zig.hook
          ];
        };

        pandoc_38 = pkgs.stdenv.mkDerivation {
          pname = "pandoc";
          version = "3.8";
          src = pkgs.fetchurl {
            url = "https://github.com/jgm/pandoc/releases/download/3.8/pandoc-3.8-linux-amd64.tar.gz";
            hash = "sha256-GgNcH30pXDU/YURh+kvBPXA8DoZTh9RDQdFVbXA95Zo=";
          };
          installPhase = ''
            mkdir -p $out/bin $out/share
            cp -r bin/* $out/bin/
            cp -r share/* $out/share/
          '';
        };

        quarto_rollback = pkgs.quarto.overrideAttrs (old: {
          version = "1.9.37";
          src = pkgs.fetchurl {
            url = "https://github.com/quarto-dev/quarto-cli/releases/download/v1.9.37/quarto-1.9.37-linux-amd64.tar.gz";
            hash = "sha256-ePzZDpg+Pn2+Pw0ZIcwQJTweynuSwg3UvCo8G8oKmvU=";
          };
          buildInputs = (old.buildInputs or [ ]) ++ [ pkgs.openssl ];
        });

        doc_pkgs = with pkgs; [
          # docs
          inputs.excalidraw-edit.packages.${system}.default
          pandoc
          quarto_rollback
        ];

        security_pkgs = with pkgs; [
          # security
          sops
        ];

        treefmt_pkgs = with pkgs; [
          # linters & formatters
          nixfmt
          prettier
          taplo
          treefmt
          zig
        ];
      in
      {
        packages = {
          default = campi_cli;
          campi-cli = campi_cli;
        };

        apps = {
          default = {
            type = "app";
            program = "${campi_cli}/bin/campi-cli";
          };
        };

        devShells = {
          default = pkgs.mkShell {
            packages = [ ] ++ runtime_pkgs ++ dev_pkgs ++ doc_pkgs ++ security_pkgs ++ treefmt_pkgs;

            shellHook = ''
              export QUARTO_PANDOC=${pandoc_38}/bin/pandoc
            '';
          };

          treefmt = pkgs.mkShell {
            packages = [ ] ++ dev_pkgs ++ treefmt_pkgs;

            shellHook = "";
          };
        };
      }
    );
}
