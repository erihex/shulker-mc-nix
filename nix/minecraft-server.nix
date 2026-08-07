{
  pkgs,
  lib,
  ...
}:

let
  mcLib = import ./minecraft-lib.nix {
    inherit lib pkgs;
  };

  # Minecraft / NeoForge

  server = pkgs.neoforgeServers.neoforge-1_21_1;

  # ATM10 server pack

  modpackArchive = builtins.path {
    path = ../minecraft/ATM10-ServerFiles-7.3.zip;
    name = "ATM10-ServerFiles-7.3.zip";
  };

  modpack =
    pkgs.runCommand "atm10-7.3-server-files"
      {
        nativeBuildInputs = [
          pkgs.unzip
        ];
      }
      ''
        set -euo pipefail

        mkdir -p "$out"

        unzip -q \
          ${modpackArchive} \
          -d "$out"
      '';

  /*
    Repository-side Minecraft directories.

    minecraft/
      mods/
      tacz/
      ...

    We inspect only directory names here. We do NOT enumerate or hardcode
    individual files.

    builtins.path makes every selected directory a proper Nix source tree.
  */

  minecraftRoot = ../minecraft;

  minecraftEntries = builtins.readDir minecraftRoot;

  minecraftDirectories = lib.filterAttrs (_name: type: type == "directory") minecraftEntries;

  localTrees = lib.mapAttrs (
    name: _type:
    builtins.path {
      path = minecraftRoot + "/${name}";
      name = "minecraft-${name}";
    }
  ) minecraftDirectories;

  # Generated configuration overlays.

  voicechatConfig = pkgs.writeText "voicechat-server.properties" ''
    port=24454
    bind_address=0.0.0.0
    voice_chat_distance=48.0
    max_voice_distance=64.0
    keep_alive=1000
  '';

  /*
    Immutable directory trees managed in the Minecraft server root.

    This is a list of semantic server-root directories, NOT a list of files.

    For every entry:

      ATM10/<name>
          +
      minecraft/<name>   (if present)
          +
      generated extraFiles
          =
      server/<name>

    So, for example:

      ATM10/mods/
          +
      minecraft/mods/
          ->
      server/mods/

    and:

      ATM10/tacz/         (if the pack ever ships one)
          +
      minecraft/tacz/
          ->
      server/tacz/
  */

  treeSpecs = {
    mods = { };

    config = {
      extraFiles = {
        "voicechat/voicechat-server.properties" = voicechatConfig;
      };
    };

    defaultconfigs = { };

    kubejs = { };

    datapacks = { };

    tacz = { };
  };

  # Build every tree through the same generic utility.

  serverTrees = lib.mapAttrs (
    name: spec:
    mcLib.mkTree {
      name = "atm10-${name}";

      base = "${modpack}/${name}";

      overlays = lib.optional (builtins.hasAttr name localTrees) localTrees.${name};

      extraFiles = spec.extraFiles or { };
    }
  ) treeSpecs;
in
{
  /*
    Networking

    TCP 25565 is handled by nix-minecraft through openFirewall.
    Simple Voice Chat requires UDP 24454.
  */

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

      # NeoForge package from nix-minecraft.

      package = server;

      /*
        JVM

        Minecraft 1.21.1 / NeoForge uses Java 21 supplied by the
        nix-minecraft NeoForge package.
      */

      jvmOpts = builtins.concatStringsSep " " [
        "-Xms8G"
        "-Xmx14G"

        "-XX:+UseZGC"
        "-XX:+UseCompactObjectHeaders"
      ];

      # server.properties

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

      # Operators

      operators.eri = {
        uuid = "2f240b6b-aef7-35aa-917f-952faeb3f8bc";

        level = 4;

        bypassesPlayerLimit = true;
      };

      /*
        Declarative immutable server trees.

        serverTrees currently produces:

          mods
          config
          defaultconfigs
          kubejs
          datapacks
          tacz

        minecraft/tacz therefore becomes:

          <server root>/tacz/

        It does NOT become:

          <server root>/mods/tacz/
      */

      symlinks = serverTrees // {
        "server-icon.png" = ../minecraft/server-icon.png;
      };

      /*
        local/ is intentionally absent.

        It remains writable persistent/runtime state instead of becoming
        an immutable /nix/store symlink.
      */
    };
  };
}
