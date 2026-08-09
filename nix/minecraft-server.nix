{
  pkgs,
  lib,
  ...
}:

let
  mc = import ./minecraft-lib.nix {
    inherit lib pkgs;
  };

  # Pack / loader

  minecraftRoot = ../minecraft;

  serverPackage = pkgs.neoforgeServers.neoforge-1_21_1.override {
    jre_headless = pkgs.corretto25;
  };

  atmArchive = builtins.path {
    path = minecraftRoot + "/ATM10-ServerFiles-7.3.zip";
    name = "ATM10-ServerFiles-7.3.zip";
  };

  atmServerPack =
    pkgs.runCommand "atm10-7.3-server-pack"
      {
        nativeBuildInputs = [ pkgs.unzip ];
      }
      ''
        set -euo pipefail

        mkdir -p "$out"
        unzip -q ${atmArchive} -d "$out"
      '';

  # Repository sources

  repoDir =
    name:
    builtins.path {
      path = minecraftRoot + "/${name}";
      name = "minecraft-${name}";
    };

  extraMods = repoDir "mods";
  extraTacz = repoDir "tacz";
  configOverrides = repoDir "config-overrides";

  /*
    Mod policy

    removeBaseJars:
      Exact upstream JARs removed before modId validation.

    replaceBaseModIds:
      Extra mods explicitly allowed to replace ATM-provided mods.
  */
  removeBaseJars = [
    "connectivity-1.21.1-7.6.jar"

    # Broken duplicate in ATM10 server pack.
    "cc-tweaked-1.21.1-forge-1.113.1.jar"

    # Client-side only / irrelevant on dedicated server.
    "Controlling-neoforge-1.21.1-19.0.5.jar"
    "ImmediatelyFast-NeoForge-1.6.11+1.21.1.jar"
    "IrisSearch-1.5.1-neoforge.jar"
    "KeybindsPurger-1.4.0-neoforge-1.21.1.jar"
    "MouseTweaks-neoforge-mc1.21-2.26.1.jar"
    "overloadedarmorbar-neoforge-1.21-2.jar"
    "rebind_narrator-1.21.1-neoforge-2025.12.23.jar"
    "CrashAssistant-neoforge-1.20.6-1.21.4-1.11.11.jar"
  ];

  replaceBaseModIds = [
    # ATM10 ships CreateDragonsPlus 1.11.3; repository provides 1.11.4.
    "create_dragons_plus"
  ];

  # Immutable mod set.
  mods = mc.mkModSet {
    name = "atm10-mods";

    baseMods = "${atmServerPack}/mods";
    extraMods = extraMods;

    inherit
      removeBaseJars
      replaceBaseModIds
      ;
  };
in
{
  networking.firewall.allowedUDPPorts = [
    24454
  ];

  services.minecraft-servers = {
    enable = true;
    eula = true;
    openFirewall = true;

    servers.shulker-atm = {
      enable = true;
      autoStart = true;
      restart = "always";

      package = serverPackage;

      jvmOpts = [
        "-Xms8G"
        "-Xmx29G"
        "-XX:+UseZGC"
        # "-XX:+ZGenerational" # Java 21 only
        "-XX:+UseCompactObjectHeaders" # Java 25 only
      ];

      serverProperties = {
        server-port = 25565;
        server-ip = "";

        gamemode = "survival";
        difficulty = "normal";

        motd = "§cч§6а§eт§aи§bк§d, §cа§6б§eо§aб§bа";

        max-players = 42;

        online-mode = false;

        # OfflineWhitelist owns access control. Keep vanilla whitelist disabled.
        white-list = false;

        enable-rcon = false;
        enforce-secure-profile = false;
        allow-flight = true;
      };

      operators.eri = {
        uuid = "2f240b6b-aef7-35aa-917f-952faeb3f8bc";
        level = 4;
        bypassesPlayerLimit = true;
      };

      /*
        nix-minecraft ownership model

        symlinks:
          Immutable, declarative content. This may safely point into /nix/store.

        files:
          nix-minecraft-managed writable copies. They are intentionally deleted
          after the service stops, so runtime-persistent state MUST NOT live here.

        Runtime-mutable trees such as config/, defaultconfigs/, kubejs/, tacz/
        and datapacks/ are therefore created by extraStartPre and are not tracked
        in .nix-minecraft-managed.
      */
      symlinks = {
        inherit mods;
        "server-icon.png" = ../minecraft/server-icon.png;
      };

      files = { };

      /*
        Persistent content policy

        seed_tree:
          Copy ATM defaults only when a destination path does not exist.
          Existing server/mod state always wins.

        overlay_tree:
          Copy repository-owned content every start. This makes explicitly
          version-controlled overrides extendable without making the whole
          runtime config tree disposable.

        Consequently:
          - ATM defaults are initial seeds.
          - config-overrides/ is authoritative for the paths it contains.
          - minecraft/tacz/ is authoritative for custom TaCZ packs it contains.
          - files created/modified only at runtime persist across restarts.
      */
      extraStartPre = ''
        set -euo pipefail

        seed_tree() {
          source="$1"
          destination="$2"

          # Some ATM server-pack directories are optional.
          if [ ! -d "$source" ]; then
            echo "Skipping absent seed directory: $source"
            return 0
          fi

          mkdir -p "$destination"

          # Seed defaults only. Existing runtime files always win.
          cp -r -n \
            --no-preserve=ownership,mode \
            "$source"/. \
            "$destination"/
        }

        overlay_tree() {
          source="$1"
          destination="$2"

          if [ ! -d "$source" ]; then
            echo "Skipping absent overlay directory: $source"
            return 0
          fi

          mkdir -p "$destination"

          # Repository-controlled files intentionally overwrite their targets.
          cp -r \
            --no-preserve=ownership,mode \
            "$source"/. \
            "$destination"/
        }

        seed_tree ${atmServerPack}/config config
        seed_tree ${atmServerPack}/defaultconfigs defaultconfigs
        seed_tree ${atmServerPack}/kubejs kubejs
        seed_tree ${atmServerPack}/datapacks datapacks

        # ATM10 7.3 may not contain tacz/, so this is deliberately optional.
        seed_tree ${atmServerPack}/tacz tacz

        # Repository TaCZ content is authoritative.
        overlay_tree ${extraTacz} tacz

        # Explicit server-specific config is authoritative.
        overlay_tree ${configOverrides} config
      '';
    };
  };
}
