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
        holochainVersionId = "v0_0_139";
        include = {
          rust = false;
        };
      };
    in

    {
      metavalues = {
        inherit holonixMain rustVersion flake-utils naersk nh-supported-systems;
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

        };

        values = {
          inherit pkgs;
        };

      });

}
