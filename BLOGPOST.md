# Packaging an Elixir/Phoenix application with Nix

## Why Nix?

- Maybe you have an existing NixOS system you want deploy to?
- Maybe you require the guarantees that Nix provides?
- You want to leverage Nix's testing ecosystem?
- Have issues with dependencies being the wrong version?
- Want an alternative to Docker?
- Just curious about it?

If any of these sound interesting to you, read on!

I won't be selling Nix to you in this article but if you're curious about it's main selling points and about businesses using it here are some great resources on that:

- [How Nix works](https://nixos.org/guides/how-nix-works/) - simple explanation about Nix's(as a package manager) features
- [nix-companies](https://github.com/ad-si/nix-companies) - github repo with a curated list of companies using Nix in production
- [What is Nix](https://shopify.engineering/what-is-nix) - article by Burke Libbey from [Shopify](https://www.shopify.com/) giving a great explanation of Nix

## Prerequisites
### Do I need NixOS to use Nix?
Short answer: no.
Nix is a cross platform package manager for (u)nix based systems.
It does support:
- any GNU/Linux distro (i686, x86_64, aarch64(ARM))
- MacOS (x86_64, aarch64(ARM / M-series chips))

NixOS does make managing/using Nix packages easier as one would expect.

### Your Elixir application
This guide assumes your Elixir application:

- only uses packages from Hex(no git/github deps)
- uses NPM for installing JS packages(not using a package manager and vendoring is fine as well)

Why no external packages? This is possible but requires packaging those dependencies using Nix separately and copying them over at an appropriate step. This requires some more trickery and thus I decided to leave this as an exercise for the reader.

Warning for new users: Nix won't allow network requests of any kind during the build steps unless they are done through appropriate Nix fetchers such as [`fetchFromGithub`](https://ryantm.github.io/nixpkgs/builders/fetchers/#fetchfromgithub).

Covering other package managers for JS would be a book in itself thus I decided that covering the most common one: `npm` would be sufficient. If you're using `yarn` you're in luck since it has even better support than `npm`. When using things such as `bun` you're going to have to put a lot of elbow grease to make it work unfortunately.

### Deployment
This guide will not cover deploying to a server. But it will show how to run your packaged application locally.

Here's some code used to deploy the test app in this article in case you're curious: [GitHub commit](https://github.com/kotkowo/kotkowo-nix/commit/26d7ab238b40bff72eec6a80fa2c6e770105558d#diff-0758a9bc8aec011e7c560660230d07529f8f5196f38ab2c20b15e6d3b57db7c4R6)

### Open to using flakes
This article will use an experimental feature: `flakes` and assumes that you have it enabled in your `nix.conf` or NixOS system configuration. Otherwise you'll have to pass `--experimental-features 'nix-command flakes'` to every `nix` invocation.
In case you're not familiar: [Flakes intro](https://nixos.wiki/wiki/Flakes)
If you're opposed to using flakes this guide still may be used but you'll need to move most of the code to `default.nix`.

## Getting started

For this article I've started a new Phoenix project and removed([here](https://github.com/ravensiris/ravensiris.xyz/commit/6d51bc467ba581b41c9c1a0de009bb9ccb1f93e7) and [here](https://github.com/ravensiris/ravensiris.xyz/commit/836faffdf138af0e9f7bd5d20de1129d7c3bf598)) the added by default github dependency(`heroicons`) as well as [added](https://github.com/ravensiris/ravensiris.xyz/commit/7b9276609f725a7bbaad6eb425b0a8d713c25823) lucide icons through `npm`.


Also generated a generic portfolio webpage using [Vercel's v0](https://v0.dev/)([commit](https://github.com/ravensiris/ravensiris.xyz/commit/41be46024e64b16085843225909a56e00be7b49c))


You can take a look at the website's code [here](https://github.com/ravensiris/ravensiris.xyz/tree/d42aa8e4506effd70edd0d152c9830de1241dc7b)

It's online at https://ravensiris.xyz/ <- just a static site for now. Hopefully I don't forget to make it interesting later.

## Let it snow
Here's the [finished product](https://github.com/ravensiris/ravensiris.xyz/blob/7840452301274578970ea06d869aa0a0941f489f/flake.nix). 
You can peek at it while reading the more comprehensive explanation about its parts:

## The inputs
```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    npmlock2nix = {
      url = "github:nix-community/npmlock2nix";
      flake = false;
    };
  };
}
```

For a flake to work you will need to add a reference to `nixpkgs` which in our case is: `github:nixos/nixpkgs/nixpkgs-unstable`. 
This reference will allow us to leverage Nix's bleeding edge package store(thus use newer version of Elixir and Erlang which may not be added to the stable store yet). Take caution since the more dynamic nature of `nixpkgs-unstable` might lead to some issues/security vulnerabilities. In case it would be a concern I suggest sticking to a stable release version and using [overrides](https://ryantm.github.io/nixpkgs/using/overrides/#sec-pkg-overrideAttrs) for package versions that are not merged in yet.


Next up we're using a commonly used library [flake-utils](https://github.com/numtide/flake-utils). It has some useful functions for packaging and is widely used by the community([GitHub search](https://github.com/search?q=language%3ANix+github%3Anumtide%2Fflake-utils&type=code)).

Finally to make Nix work with `npm` lockfiles we're going to use [npmlock2nix](https://github.com/nix-community/npmlock2nix). Which is unfortunately not packaged as a flake. But we still can utilize it by passing `flake = false;`.

As you might notice, you can treat the `inputs` section as a way to declare imports from other Nix repositories. Dependencies used here will be tracked in `flake.lock` file and will remain reproducible.


## The outputs

```nix
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
      nodejs = pkgs.nodejs_22;
      npm2nix = pkgs.callPackage npmlock2nix {};
    in {
      # ...
    }
```

For the output we're utilizing `eachDefaultSystem` from `flake-utils`.
`eachDefaultSystem` will generate an output for each architecture supported by Nix.

For someone new to Nix it might not look like it but we're actually passing an argument to `eachDefaultSystem` in form of a lambda function that takes a single `system` parameter. If you're unfamiliar with the syntax read on [here](https://nixos.org/guides/nix-pills/05-functions-and-imports#nameless-and-single-parameter).


So when we're defining a `default` package it would generate something like this:

```
nix-repl> outputs.packages.<TAB>
outputs.packages.aarch64-darwin  outputs.packages.aarch64-linux   outputs.packages.x86_64-darwin   outputs.packages.x86_64-linux

nix-repl> outputs.packages.x86_64-linux.<TAB>
outputs.packages.x86_64-linux.default      outputs.packages.x86_64-linux.nixosModule
```

Simple but nifty.

If you're unfamiliar with `let ... in {expr}` blocks they are a way that we can define variables in Nix. So:

```nix
let 
    x = 8080;
in
{
    service.my-service.port = x;
}
```

would set the option `port` from `service.my-service` to the value of `8080`.
In Nix you can nest and shadow variables:

```nix
let
    x = 8080;
in
{
    service.my-service = let
        x = 9090;
        y = true;
    in 
    {
        port = x;
        openFirewall = y;
    };
}
```

So the value of `service.my-service.port` will be set to `9090` and `service.my-service.openFirewall` will equal `true`.

So in our first `let ... in {}` we'll be setting the dependency versions:

Setting the `pkgs` is important as it will be easier to refer to packages below.
```nix
pkgs = nixpkgs.legacyPackages.${system};
```

Here we are setting the version of Erlang to OTP27(we are not locking to a specific minor version as it's not really needed but it's possible using overrides).
The version of elixir will be the newest one available in `nixpkgs-unstable` for OTP27. As it's not important for this project I didn't lock it to any specific one(again possible with overrides). And we're using Node with major version 22(you might need to adjust depending on your `package.lock` version).
```nix
erl = pkgs.beam.interpreters.erlang_27;
erlangPackages = pkgs.beam.packagesWith erl;
elixir = erlangPackages.elixir;
nodejs = pkgs.nodejs_22;
```

And finally we're importing `npmlock2nix`.
```nix
npm2nix = pkgs.callPackage npmlock2nix {};
```

You can read a bit more about `callPackage` here: [callPackage design pattern](https://nixos.org/guides/nix-pills/13-callpackage-design-pattern)

Also in case you're unfamiliar with the syntax of a lambda function in nix read here: 

## The package set
Now theres a bunch of code inside our lambda `eachDefaultSystem(system: {...})`
Let's focus on the `package = ...` part of it for now.

```nix
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
  # inner expression
}
```

We're making use of the `let ... in {}` block to define some more variables that are only relevant to our package definition. So everything in the code block above will be available inside `# inner expression`.

The first one is `version = "0.1.0";` which is our application's version. I strongly suggest following [semantic versioning](https://semver.org/) for this as well as keeping it same as what we have in our `mix.exs`.

Second one is `src = ./.`. In nix values starting with a `.` refer to the Git repo's root. So you can imagine that `src` is set to a copy of your repo's directory.

Third one `mixFodDeps` is a special definition that utilizes `fetchMixDeps` function built in to `nixpkgs`. It will fetch all the dependencies we declared in our `mix.exs` and lock that to a hash `sha256 = "..."`.

Don't worry. You don't need to know how that value is computed. If you don't know what it is just set `sha256 = "";`(empty string). When invoking `nix build` it will assume a default hash value and then fail while printing the computed value.

`pname` is arbitrary. Just set it to whatever makes sense to you.

`inherit version src` will copy over values of `version` and `src` from above. It's the same as you'd set it like this:

```nix
mixFodDeps = erlangPackages.fetchMixDeps {
  version = version;
  src = src;
  pname = "ri-elixir-deps";
  sha256 = "sha256-8aSihmaxNOadMl7+0y38B+9ahh0zNowScwvGe0npdPw=";
};
```

The fourth one won't make sense yet.

```nix
translatedPlatform =
  {
    aarch64-darwin = "macos-arm64";
    aarch64-linux = "linux-arm64";
    armv7l-linux = "linux-armv7";
    x86_64-darwin = "macos-x64";
    x86_64-linux = "linux-x64";
  }
  .${system};
```

Just notice that we're calling the set(`{}`) with `${system}`.
It functions the same as the below elixir code:

```elixir
iex(1)> system = "x86_64-linux"
"x86_64-linux"
iex(2)> translated_platform = %{
...(2)>     "aarch64-darwin" => "macos-arm64",
...(2)>     "aarch64-linux" => "linux-arm64",
...(2)>     "armv7l-linux" => "linux-armv7",
...(2)>     "x86_64-darwin" => "macos-x64",
...(2)>     "x86_64-linux" => "linux-x64"
...(2)> }[system]
"linux-x64"
```


Lastly we have this block:

```nix
npmDeps = npm2nix.v2.node_modules {
  src = ./assets;
  nodejs = nodejs;
};
```

Here we're utilizing `npmlock2nix.v2.node_modules` function to turn our `package.lock` into something Nix can understand. Later we can access it as a reference to a populated `node_modules` directory(that is exactly like you'd run `npm install` but managed by Nix instead). Read more on how the `npmlock2nix.v2.node_modules` works [here](https://github.com/nix-community/npmlock2nix/blob/master/API.md#node_modules).

## Finally a package definition

Now let's delve inside `# inner block`.

```nix
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

# ignore this for now
nixosModule = {...};
```

Naming your package exposed in Nix flake's output `default` is a common pattern for flakes. But this name is completely arbitrary. You can change it to whatever you want. But keep in mind most Nix users will be looking for a `default` output.

Our `default` package definition is using `mixRelease` function again built in to `nixpkgs`. We're copying the values of `version`, `src`, `mixFodDeps` from `let` blocks above. `pname` value again is arbitrary(but keep it unique and sensible for fellow Nix users sake).

Interesting part here is the `preInstall` definition. It's essentially a fancy shell script. Let's go over line by line:

```nix
"ln -s ${pkgs.tailwindcss}/bin/tailwindcss _build/tailwind-${translatedPlatform}"
```

Why are we copying anything to a `_build/` directory? Seems strange at first. But it's a workaround for the fact that Nix doesn't allow any network requests during building(with exception for fetchers).

The tailwind library we're using in our `mix.exs` deps(`{:tailwind, "~> 0.2", runtime: Mix.env() == :dev}`) is trying to download a copy of tailwind executable from [here](https://github.com/tailwindlabs/tailwindcss/releases/) if it doesn't find it already. This will fail during Nix's build step. Thus we need to supply a copy of tailwind from Nix instead. If you looked at the tailwind releases page you'd notice that they provide binaries for multiple architechtures such as: `linux-x64`. Nix does in fact support most of these architectures but the naming scheme is different. `linux-x64` would be `x86_64-linux` in Nix terms. Thus we're utilizing that `translatedPlatform` variable to rename the symlink so that Elixir's tailwind library may find it.

What symlink? `${pkgs.tailwindcss}/bin/tailwindcss` will actually expand to something like this `/nix/store/p0l7kjqq5ppc8wgrrj889bw91ds9pgc1-tailwindcss-3.4.3/bin/tailwindcss`. This points to a valid path in our systems Nix store. By symlinking it we don't waste storage on additional copies and other programs that share the same version of tailwind have an oppurtunity to reuse it.


We're doing the exact same thing for `esbuild`.
```nix
"ln -s ${pkgs.esbuild}/bin/esbuild _build/esbuild-${translatedPlatform}"
```

Next we're symlinking the `node_modules` directory we've generated with `npmlock2nix`.

```nix
"ln -s ${npmDeps}/node_modules assets/node_modules"
```

This way ESBuild will be able to find all the dependencies needed.

Next we're running `assets.deploy` as per [Phoenix's docs](https://hexdocs.pm/phoenix/deployment.html#compiling-your-application-assets)

```nix
"${elixir}/bin/mix assets.deploy"
```

Lastly we're running
```nix
"${elixir}/bin/mix phx.gen.release"
```

Which will put some additonal scripts(`server`, `migrate`) into our output directory which will make running our app easier.

## Let's build and run

If you've been following everything you should already have all the pieces that are required to build our package. Now checkout everything in a git repo and run `nix build`. It will take a while and you might need change some `sha256` values. When you finally get a successful build a new symlinked directory should appear in the root of your project `result`.

Our application's binary should be now available under `result/bin/server`.
Try running it. It should fail due to missing environment variables. Let's set them for testing:

```sh
# random value. doesn't really matter but it's mandatory to be set.
export RELEASE_COOKIE="$(dd if=/dev/urandom bs=64 count=1 | base64)"

# here replace to a connect to a local instance of postgres running on your system
export DATABASE_URL="postgres:///postgres"

# required secret
export SECRET_KEY_BASE="$(dd if=/dev/urandom bs=64 count=1 | base64)"

result/bin/server
```

If everything was set properly a server should be running at `http://localhost:4000`.

Now you can publish your repository on github and use it as an input for your system/server configuration.

## For NixOS users
As I stated above NixOS users can enjoy even more power than regular `nix` users.
For that we can create a NixOS module which will allow NixOS users to configure our web server from their Nix configuration instead of using environmental variables.

The final piece is this:

```nix
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
      description = "A file containing the Phoenix Secret Key Base. This should be secret, and not kept in the nix store";
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
```

The name `nixosModule` is arbitrary. But it's a common pattern to name it this way so other Nix users can easily find it.

Our NixOS module takes some parameters:

```nix
{
  config,
  lib,
  pkgs,
  ...
}: {}
```

You should not worry about them. They will be injected by Nix automatically when user of our module imports it like this:

```nix
# somewhere inside their host configuration
imports = [
    our-nixos-module.outputs.packages.x86_64-linux.nixosModule
];
```

Then what's left is 2 parts:

- definition of configurable options
- the configuration that get's injected into the host when our service gets enabled

## The options definition

```nix
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
```

This block is pretty self explanatory once you understand what it does. But if in doubt please read [this](https://nlewo.github.io/nixos-manual-sphinx/development/option-declarations.xml.html).

## The config
The config part that gets injected into hosts system is further split into multiple parts:

### Assertions

```nix
assertions = [
  {
    assertion = cfg.secretKeyBaseFile != "";
    message = "A base key file is necessary";
  }
];
```

They allow you to give helpful messages to the user when required attributes are not set. NixOS will also make runtime assertions on it's own(e.g. it will exit when you try to access an unassigned variable).


### User and group definitions

To avoid running the server as `root` or a user in `sudoers` file we create one that will only be used for the purpose of running our server.

```nix
users.users.${user} = {
  isSystemUser = true;
  group = user;
  home = dataDir;
  createHome = true;
};
users.groups.${user} = {};
```

For additonal reference you may consult [NixOS option search](https://search.nixos.org/options?channel=24.05&from=0&size=50&sort=relevance&type=packages&query=users.users)

### SystemD unit

For the most important part we wrap our server in a [SystemD unit](https://wiki.archlinux.org/title/Systemd#Writing_unit_files).
Here I send you off to reading some [preexisting unit files](https://github.com/NixOS/nixpkgs/blob/c7e80fc665792a01d5945018c04e0459b62a02b9/nixos/modules/services/web-apps/plausible.nix#L189) and [SystemD documentation](https://www.freedesktop.org/software/systemd/man/latest/systemd.unit.html). Making units can be hard but the template used for this article should be sufficient for most purposes.

```nix
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
```

## Conclusion

In this article, we've explored how to package an Elixir/Phoenix application using Nix. We've covered:

1. Setting up the necessary inputs for our Nix flake
2. Defining our package and its dependencies
3. Creating a NixOS module for easier deployment on NixOS systems
4. Handling asset compilation and dependency management within the Nix ecosystem

By leveraging Nix, we've created a reproducible build process for our Elixir application, ensuring consistent deployments across different environments. This approach offers several benefits, including:

- Improved dependency management
- Consistent builds across different machines
- Easy integration with NixOS systems
- Potential for leveraging Nix's testing ecosystem

While the learning curve for Nix can be steep, the long-term benefits in terms of reproducibility and maintainability make it a valuable tool in your deployment arsenal, especially for complex Elixir/Phoenix applications.

## Additional Resources

To further your understanding of Nix and its ecosystem, here are some helpful resources:

1. [Nix Pills](https://nixos.org/guides/nix-pills/) - A comprehensive guide to Nix, starting from the basics
2. [NixOS Wiki](https://nixos.wiki/) - A community-driven wiki with various guides and best practices
3. [Phoenix Deployment Guides](https://hexdocs.pm/phoenix/deployment.html) - Official Phoenix deployment documentation
4. [nix.dev](https://nix.dev/index.html) - Learn nix by examples
5. [Nix Flakes: Exposing and using NixOS Modules](https://xeiaso.net/blog/nix-flakes-3-2022-04-07/) - great article about NixOS modules
6. [Plausible service nix definition](https://github.com/NixOS/nixpkgs/blob/c7e80fc665792a01d5945018c04e0459b62a02b9/nixos/modules/services/web-apps/plausible.nix) - [Plausible](https://plausible.io/)'s nix service definition


Remember that the Nix ecosystem is constantly evolving, so it's always a good idea to check the official documentation and community resources for the most up-to-date information.

Happy coding and deploying with Nix and Elixir!
