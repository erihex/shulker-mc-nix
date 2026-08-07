{
  pkgs,
  lib,
  ...
}:

let
  mcLib = import ./minecraft-lib.nix { inherit lib pkgs; };

  minecraftVersion = "1.21.1";
  neoforgeVersion = "21.1.206";

  neoforgePackageName =
    "neoforge-"
    + lib.replaceStrings [ "." ] [ "_" ] minecraftVersion
    + "-"
    + lib.replaceStrings [ "." ] [ "_" ] neoforgeVersion;

  server = pkgs.neoforgeServers.${neoforgePackageName};

  modpackArchive = ../minecraft/ATM10-ServerFiles-7.3.zip;

  modpack =
    pkgs.runCommand "atm10-7.3-server-files"
      {
        nativeBuildInputs = [ pkgs.unzip ];
      }
      ''
        mkdir -p "$out"
        unzip -q ${modpackArchive} -d "$out"
      '';

  # Repository-controlled directories below minecraft/ are discovered
  # automatically. At the moment this picks up mods/ and tacz/, but adding
  # another directory later does not require adding every file by hand.
  localMinecraftDirs = lib.filterAttrs (_: type: type == "directory") (builtins.readDir ../minecraft);

  localTrees = lib.mapAttrs (name: _: ../minecraft + "/${name}") localMinecraftDirs;

  voicechatConfig = pkgs.writeText "voicechat-server.properties" ''
    port=24454
    bind_address=0.0.0.0
    voice_chat_distance=48.0
    max_voice_distance=64.0
    keep_alive=1000
  '';

  # One declarative table describes all immutable server-root trees.
  # There is no special mergedMods/mergedConfig implementation.
  #
  # ATM-owned trees use the corresponding directory from the extracted pack as
  # their base. If a same-named repository directory exists (mods/, tacz/, ...)
  # it is overlaid recursively and automatically.
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

    # TaCZ gun packs belong in <server-root>/tacz/, not mods/.
    tacz = { };
  };

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
  networking.firewall.allowedUDPPorts = [ 24454 ];

  services.minecraft-servers = {
    enable = true;
    eula = true;
    openFirewall = true;

    servers.shulker-atm = {
      enable = true;
      autoStart = true;
      restart = "always";

      package = server;

      jvmOpts = builtins.concatStringsSep " " [
        "-Xms8G"
        "-Xmx14G"
        "-XX:+UseZGC"
        "-XX:+ZGenerational"
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

      # All immutable directory trees are wired into the server root from the
      # single data-driven serverTrees attrset.
      symlinks = serverTrees // {
        "server-icon.png" = ../minecraft/server-icon.png;
      };

      # local/ remains writable persistent state and is intentionally not
      # managed by Nix.
    };
  };
}
