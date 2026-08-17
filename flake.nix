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
        ];

        doc_pkgs = with pkgs; [
          # docs
          inputs.excalidraw-edit.packages.${system}.default
          pandoc
          quarto
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
        devShells = {
          default = pkgs.mkShell {
            packages = [ ] ++ runtime_pkgs ++ dev_pkgs ++ doc_pkgs ++ security_pkgs ++ treefmt_pkgs;

            shellHook = "";
          };

          treefmt = pkgs.mkShell {
            packages = [ ] ++ dev_pkgs ++ treefmt_pkgs;

            shellHook = "";
          };
        };
      }
    );
}
