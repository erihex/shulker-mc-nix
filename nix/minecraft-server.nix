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
    jre_headless = pkgs.jdk21_headless;
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

  /*
    Mod policy

    removeBaseJars:
      Exact upstream JARs removed before modId validation.

    replaceBaseModIds:
      Extra mods explicitly allowed to replace ATM-provided mods.
  */

  removeBaseJars = [
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
  ];

  replaceBaseModIds = [
    # ATM10 ships CreateDragonsPlus 1.11.3; repository provides 1.11.4.
    "create_dragons_plus"
  ];

  # Derived trees

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
      "voicechat/voicechat-server.properties" = voicechatConfig;
    };
  };

  tacz = mc.mkOverlayTree {
    name = "atm10-tacz";

    sources = [
      "${atmServerPack}/tacz"
      extraTacz
    ];
  };

  /*
    nix-minecraft content model

    symlinks:
      immutable content which should remain read-only.

    files:
      content copied into the server directory and therefore writable at
      runtime. Config/KubeJS/TaCZ belong here because mods may update them.
  */

  immutableContent = {
    inherit mods;

    "server-icon.png" = ../minecraft/server-icon.png;
  };

  writableContent = {
    inherit config tacz;

    defaultconfigs = "${atmServerPack}/defaultconfigs";

    kubejs = "${atmServerPack}/kubejs";

    datapacks = "${atmServerPack}/datapacks";
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
        "-Xmx14G"
        "-XX:+UseZGC"
        "-XX:+ZGenerational" # Java 21 only
        # "-XX:+UseCompactObjectHeaders" # Java 25 only
      ];

      serverProperties = {
        server-port = 25565;
        server-ip = "";

        gamemode = "survival";
        difficulty = "normal";

        motd = "§cч§6а§eт§aи§bк§d, §cа§6б§eо§aб§bа";

        max-players = 42;

        online-mode = false;
        white-list = false;
        enable-rcon = false;
        enforce-secure-profile = false;
      };

      operators.eri = {
        uuid = "2f240b6b-aef7-35aa-917f-952faeb3f8bc";

        level = 4;
        bypassesPlayerLimit = true;
      };

      # Immutable store-backed content.
      symlinks = immutableContent;

      # Writable copies managed by nix-minecraft.
      files = writableContent;

      /*
        Runtime state intentionally remains unmanaged:
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
