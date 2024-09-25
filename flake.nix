{
  description = "RavensIris' home page";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    npmlock2nix = {
      url = "github:nix-community/npmlock2nix";
      flake = false;
    };
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    npmlock2nix,
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
      erl = pkgs.beam.interpreters.erlang_27;
      erlangPackages = pkgs.beam.packagesWith erl;
      elixir = erlangPackages.elixir;
      npm2nix = import npmlock2nix {pkgs = pkgs;};
      nodejs = pkgs.nodejs_22;
    in {
      packages = let
        version = "0.1.0";
        src = ./.;
        mixFodDeps = erlangPackages.fetchMixDeps {
          inherit version src;
          pname = "ri-elixir-deps";
          sha256 = "sha256-XVbCVLmiZfXlpK1l2z/0uCULWfpmwVy2Wn86TbFYI0c=";
        };
        translatedPlatform =
          {
            aarch64-darwin = "macos-arm64";
            aarch64-linux = "linux-arm64";
            armv7l-linux = "linux-armv7";
            x86_64-darwin = "macos-x64";
            x86_64-linux = "linux-x64";
          }
          .${system};
        npmDeps = npm2nix.v2.node_modules {
          src = ./assets;
          nodejs = nodejs;
        };
      in {
        default = erlangPackages.mixRelease {
          inherit version src mixFodDeps;
          pname = "ravensiris-homepage";

          preInstall = ''
            ln -s ${pkgs.tailwindcss}/bin/tailwindcss _build/tailwind-${translatedPlatform}
            ln -s ${pkgs.esbuild}/bin/esbuild _build/esbuild-${translatedPlatform}
            ln -s ${npmDeps}/node_modules assets/node_modules

            ${elixir}/bin/mix assets.deploy
            ${elixir}/bin/mix phx.gen.release
          '';
        };
      };
    });
}
