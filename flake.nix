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
    let
      nh-supported-systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin"];

      rustVersion = "1.60.0";

      wasmTarget = "wasm32-unknown-unknown";

      holonixMain = import holonix {
        holochainVersionId = "v0_0_143";
        include = {
          rust = false;
        };
      };
    in

    {
      metavalues = {
        inherit holonixMain rustVersion flake-utils naersk nh-supported-systems wasmTarget;
      };
    }

    //

    flake-utils.lib.eachSystem nh-supported-systems (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            rust-overlay.overlay
            cargo2nix.overlay
          ];
        };
      in

      {
        shells = {

          holochainDevShell = {
            extraBuildInputs ? [],
            LD_LIBRARY_PATH ? null,
          }:
          pkgs.mkShell {
            inputsFrom = [
              holonixMain.main
            ];

            buildInputs = [
              holonixMain.pkgs.binaryen
            ] ++ (with pkgs; [
              miniserve
              nixUnstable # holonix provides a pre-flake nix
              # cargo2nix.defaultPackage.${system}
              (rust-bin.stable.${rustVersion}.default.override {
                extensions = ["rust-src"];
                targets = [ wasmTarget ];
              })
            ]) ++ extraBuildInputs;

            shellHook = ''
              export CARGO_HOME=~/.cargo
              export CARGO_TARGET_DIR=target
            '';

            inherit LD_LIBRARY_PATH;
          };

          rustDevShell = {
            extraBuildInputs ? [],
          }: pkgs.mkShell {
            buildInputs = [
              (pkgs.rust-bin.stable.${rustVersion}.default.override {
                extensions = ["rust-src"];
                targets = [ wasmTarget ];
              })
              cargo2nix.defaultPackage.${system}
            ] ++ extraBuildInputs;
          };

        };

        values = {
          inherit pkgs;
        };

      });

}
