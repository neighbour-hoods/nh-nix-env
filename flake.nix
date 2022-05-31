{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    holonix = {
      url = "github:holochain/holonix";
      flake = false;
    };
    rust-overlay.url = "github:oxalica/rust-overlay";
    cargo2nix.url = "github:cargo2nix/cargo2nix";
    naersk.url = "github:nix-community/naersk";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };

  outputs = { nixpkgs, flake-utils, holonix, rust-overlay, cargo2nix, naersk, ... }:
    flake-utils.lib.eachSystem ["x86_64-linux" "aarch64-linux" "x86_64-darwin"] (system:
      let
        holonixMain = import holonix {
          holochainVersionId = "v0_0_139";
          include = {
            rust = false;
          };
        };

        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            rust-overlay.overlay
            cargo2nix.overlay
          ];
        };

        rustVersion = "1.60.0";

        wasmTarget = "wasm32-unknown-unknown";

      in

      {
        packages = {

          holochainDevShell = pkgs.mkShell {
            inputsFrom = [
              holonixMain.main
            ];

            buildInputs = [
              holonixMain.pkgs.binaryen
            ] ++ (with pkgs; [
              miniserve
              nodePackages.rollup
              wasm-pack
              # cargo2nix.defaultPackage.${system}
              (rust-bin.stable.${rustVersion}.default.override {
                targets = [ wasmTarget ];
              })
            ]);

            shellHook = ''
              export CARGO_HOME=~/.cargo
              export CARGO_TARGET_DIR=target
            '';
          };

          rustDevShell = pkgs.mkShell {
            buildInputs = [
              pkgs.rust-bin.stable.${rustVersion}.default
              cargo2nix.defaultPackage.${system}
            ];
          };

          values = {
            inherit pkgs holonixMain rustVersion;
          };

        };

      });

}
