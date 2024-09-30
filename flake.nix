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
      npm2nix = pkgs.callPackage npmlock2nix {};
      nodejs = pkgs.nodejs_22;
    in {
      packages = let
        version = "0.1.0";
        src = ./.;
        mixFodDeps = erlangPackages.fetchMixDeps {
          inherit version src;
          pname = "ri-elixir-deps";
          sha256 = "sha256-8aSihmaxNOadMl7+0y38B+9ahh0zNowScwvGe0npdPw=";
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
      in rec {
        default = erlangPackages.mixRelease {
          inherit version src mixFodDeps;
          pname = "ravensiris-web";

          preInstall = ''
            ln -s ${pkgs.tailwindcss}/bin/tailwindcss _build/tailwind-${translatedPlatform}
            ln -s ${pkgs.esbuild}/bin/esbuild _build/esbuild-${translatedPlatform}
            ln -s ${npmDeps}/node_modules assets/node_modules

            ${elixir}/bin/mix assets.deploy
            ${elixir}/bin/mix phx.gen.release
          '';
        };
        nixosModule = {
          config,
          lib,
          pkgs,
          ...
        }: let
          cfg = config.services.ravensiris-web;
          user = "ravensiris-web";
          dataDir = "/var/lib/ravensiris-web";
        in {
          options.services.ravensiris-web = {
            enable = lib.mkEnableOption "ravensiris-web";
            port = lib.mkOption {
              type = lib.types.port;
              default = 4000;
              description = "Port to listen on, 4000 by default";
            };
            secretKeyBaseFile = lib.mkOption {
              type = lib.types.path;
              description = "A file contianing the Phoenix Secret Key Base. This should be secret, and not kept in the nix store";
            };
            databaseUrlFile = lib.mkOption {
              type = lib.types.path;
              description = "A file containing the URL to use to connect to the database";
            };
            host = lib.mkOption {
              type = lib.types.str;
              description = "The host to configure the router generation from";
            };
          };
          config = lib.mkIf cfg.enable {
            assertions = [
              {
                assertion = cfg.secretKeyBaseFile != "";
                message = "A base key file is necessary";
              }
            ];

            environment.systemPackages = [default];

            users.users.${user} = {
              isSystemUser = true;
              group = user;
              home = dataDir;
              createHome = true;
            };
            users.groups.${user} = {};

            systemd.services = {
              ravensiris-web = {
                description = "Start up the homepage";
                wantedBy = ["multi-user.target"];
                script = ''
                  # Elixir does not start up if `RELEASE_COOKIE` is not set,
                  # even though we set `RELEASE_DISTRIBUTION=none` so the cookie should be unused.
                  # Thus, make a random one, which should then be ignored.
                  export RELEASE_COOKIE=$(tr -dc A-Za-z0-9 < /dev/urandom | head -c 20)
                  export SECRET_KEY_BASE="$(< $CREDENTIALS_DIRECTORY/SECRET_KEY_BASE )"
                  export DATABASE_URL="$(< $CREDENTIALS_DIRECTORY/DATABASE_URL )"

                  ${default}/bin/migrate
                  ${default}/bin/server
                '';
                serviceConfig = {
                  User = user;
                  WorkingDirectory = "${dataDir}";
                  Group = user;
                  LoadCredential = [
                    "SECRET_KEY_BASE:${cfg.secretKeyBaseFile}"
                    "DATABASE_URL:${cfg.databaseUrlFile}"
                  ];
                };

                environment = {
                  PHX_HOST = cfg.host;
                  # Disable Erlang's distributed features
                  RELEASE_DISTRIBUTION = "none";
                  # Additional safeguard, in case `RELEASE_DISTRIBUTION=none` ever
                  # stops disabling the start of EPMD.
                  ERL_EPMD_ADDRESS = "127.0.0.1";
                  # Home is needed to connect to the node with iex
                  HOME = "${dataDir}";
                  PORT = toString cfg.port;
                };
              };
            };
          };
        };
      };
    });
}
