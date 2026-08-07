{
  pkgs,
  lib,
  ...
}:

let
  mc = import ./minecraft-lib.nix {
    inherit lib pkgs;
  };

  /*
    ──────────────────────────────────────────────────────────────────────────
    Pack / loader
    ──────────────────────────────────────────────────────────────────────────
  */

  minecraftRoot = ../minecraft;

  # Latest NeoForge for Minecraft 1.21.1 provided by the pinned nix-minecraft
  # flake. This currently resolves to 21.1.248 in this repository.
  serverPackage =
    pkgs.neoforgeServers.neoforge-1_21_1;

  atmArchive = builtins.path {
    path = minecraftRoot + "/ATM10-ServerFiles-7.3.zip";
    name = "ATM10-ServerFiles-7.3.zip";
  };

  atmServerPack = pkgs.runCommand "atm10-7.3-server-pack" {
    nativeBuildInputs = [ pkgs.unzip ];
  } ''
    set -euo pipefail

    mkdir -p "$out"
    unzip -q ${atmArchive} -d "$out"
  '';

  /*
    ──────────────────────────────────────────────────────────────────────────
    Repository sources
    ──────────────────────────────────────────────────────────────────────────
  */

  repoDir =
    name:
    builtins.path {
      path = minecraftRoot + "/${name}";
      name = "minecraft-${name}";
    };

  extraMods = repoDir "mods";
  extraTacz = repoDir "tacz";

  /*
    ──────────────────────────────────────────────────────────────────────────
    Mod policy
    ──────────────────────────────────────────────────────────────────────────

    Keep these two sets small and explicit.

    removeBaseJars:
      Exact JARs to remove from ATM10 before any duplicate-modId validation.

    replaceBaseModIds:
      modIds for which minecraft/mods intentionally replaces ATM10's JAR.

    Everything else is fail-closed:
      an extra mod already present in ATM10 causes the Nix build to fail.
  */

  removeBaseJars = [
    # ATM10 7.3 contains two CC:Tweaked versions. Keep 1.120.0 and remove the
    # obsolete 1.113.1 before validating the base mod set.
    "cc-tweaked-1.21.1-forge-1.113.1.jar"
  ];

  replaceBaseModIds = [
    # Examples, only add entries intentionally:
    #
    # "create_dragons_plus"
    # "carryon"
    "create_dragons_plus"
  ];

  /*
    ──────────────────────────────────────────────────────────────────────────
    Derived server trees
    ──────────────────────────────────────────────────────────────────────────
  */

  mods = mc.mkModSet {
    name = "atm10-mods";
    baseMods = "${atmServerPack}/mods";
    extraMods = extraMods;

    inherit
      removeBaseJars
      replaceBaseModIds
      ;
  };

  voicechatConfig = pkgs.writeText "voicechat-server.properties" ''
    port=24454
    bind_address=0.0.0.0
    voice_chat_distance=48.0
    max_voice_distance=64.0
    keep_alive=1000
  '';

  config = mc.mkOverlayTree {
    name = "atm10-config";

    sources = [
      "${atmServerPack}/config"
    ];

    files = {
      "voicechat/voicechat-server.properties" =
        voicechatConfig;
    };
  };

  tacz = mc.mkOverlayTree {
    name = "atm10-tacz";

    sources = [
      # ATM10 currently does not need to ship tacz/, but keeping the base
      # source here makes the layout forward-compatible.
      "${atmServerPack}/tacz"
      extraTacz
    ];
  };

  /*
    Trees used unchanged from the official server pack.
  */
  atmTrees = {
    defaultconfigs = "${atmServerPack}/defaultconfigs";
    kubejs = "${atmServerPack}/kubejs";
    datapacks = "${atmServerPack}/datapacks";
  };

  managedTrees =
    atmTrees
    // {
      inherit mods config tacz;
    };
in
{
  /*
    ──────────────────────────────────────────────────────────────────────────
    Networking
    ──────────────────────────────────────────────────────────────────────────
  */

  # TCP 25565 is opened by nix-minecraft via openFirewall.
  # Simple Voice Chat needs UDP separately.
  networking.firewall.allowedUDPPorts = [
    24454
  ];

  /*
    ──────────────────────────────────────────────────────────────────────────
    Minecraft
    ──────────────────────────────────────────────────────────────────────────
  */

  services.minecraft-servers = {
    enable = true;

    # nix-minecraft manages eula.txt.
    eula = true;

    openFirewall = true;

    servers.shulker-atm = {
      enable = true;
      autoStart = true;
      restart = "always";

      package = serverPackage;

      /*
        Keep JVM tuning intentionally conservative while stabilising the pack.
      */
      jvmOpts = [
        "-Xms8G"
        "-Xmx14G"
      ];

      /*
        nix-minecraft generates server.properties from this set.
      */
      serverProperties = {
        server-port = 25565;
        server-ip = "";

        gamemode = "survival";
        difficulty = "normal";

        motd =
          "§cч§6а§eт§aи§bк§d, §cа§6б§eо§aб§bа";

        max-players = 42;

        online-mode = false;
        white-list = false;
        enable-rcon = false;
        enforce-secure-profile = false;
      };

      operators.eri = {
        uuid =
          "2f240b6b-aef7-35aa-917f-952faeb3f8bc";

        level = 4;
        bypassesPlayerLimit = true;
      };

      /*
        Declarative immutable server content.

        nix-minecraft itself owns eula.txt and server.properties, so neither is
        duplicated here.
      */
      symlinks =
        managedTrees
        // {
          "server-icon.png" =
            ../minecraft/server-icon.png;
        };

      /*
        Runtime state remains writable and unmanaged:
          local/
          world/
          logs/
          crash-reports/
          serverconfig/
          etc.
      */
    };
  };
}
