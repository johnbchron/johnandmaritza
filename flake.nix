{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
    crane.url = "github:ipetkov/crane";
    devshell.url = "github:numtide/devshell";
  };

  outputs = { nixpkgs, rust-overlay, devshell, flake-utils, crane, ... }: 
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          (import rust-overlay)
          devshell.overlays.default
        ];
      };

      toolchain_fn = p: p.rust-bin.selectLatestNightlyWith (toolchain: toolchain.default.override {
        extensions = [ "rust-src" "rust-analyzer" ];
      });
      minimal_toolchain_fn = p: p.rust-bin.selectLatestNightlyWith (toolchain: toolchain.minimal.override {
        extensions = [ "rustfmt" "clippy" ];
      });


      craneLib = (crane.mkLib pkgs).overrideToolchain minimal_toolchain_fn;

      src = craneLib.cleanCargoSource ./.;

      server_meta = craneLib.crateNameFromCargoToml {
        cargoToml = ./crates/server/Cargo.toml;
      };
      server_args = {
        inherit src;
        inherit (server_meta) pname version;

        strictDeps = true;
        doCheck = false;
      };
      cargoArtifacts = craneLib.buildDepsOnly server_args;
      server = craneLib.buildPackage (server_args // { inherit cargoArtifacts; });

      server-container = pkgs.dockerTools.buildLayeredImage {
        name = "johnandmaritza";
        tag = "latest";
        contents = [ server ];
        config = {
          Entrypoint = [ "${pkgs.tini}/bin/tini" server_meta.pname "--" ];
          # Entrypoint = [ server_meta.pname ];
          WorkingDir = "${server}/bin";
        };
      };
    in {
      devShells.default = pkgs.devshell.mkShell {
        packages = [ (toolchain_fn pkgs) pkgs.gcc pkgs.tailwindcss_4 ];
        motd = "\n  Welcome to the {2}johnandmaritza{reset} shell.\n";
      };
      packages = {
        inherit server server-container;
        default = server;
      };
    });
}
