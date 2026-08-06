{
  pkgs,
  lib,
  ...
}:

let
  # ATM10 7.3 server pack from minecraft/ATM10-ServerFiles-7.3.zip.
  # The archive shown for this deployment uses Minecraft 1.21.1 and
  # NeoForge 21.1.206, so keep the loader pinned instead of following
  # nix-minecraft's moving "latest" alias.
  minecraftVersion = "1.21.1";
  neoforgeVersion = "21.1.206";

  neoforgePackageName =
    "neoforge-"
    + lib.replaceStrings [ "." ] [ "_" ] minecraftVersion
    + "-"
    + lib.replaceStrings [ "." ] [ "_" ] neoforgeVersion;

  server = pkgs.neoforgeServers.${neoforgePackageName};

  modpackArchive = ../minecraft/ATM10-ServerFiles-7.3.zip;
  extraModsDir = ../minecraft/mods;

  modpack =
    pkgs.runCommand "atm10-7.3-server-files"
      {
        nativeBuildInputs = [ pkgs.unzip ];
      }
      ''
        mkdir -p "$out"
        unzip -q ${modpackArchive} -d "$out"
      '';

  # ATM10's own mods plus every additional JAR committed under minecraft/mods/.
  # There is deliberately no exclusion list here: the old exclusions belonged
  # to the previous Integrated MC deployment, not to ATM10.
  mergedMods = pkgs.runCommand "atm10-7.3-merged-mods" { } ''
    mkdir -p "$out"

    if [ -d ${modpack}/mods ]; then
      cp -a ${modpack}/mods/. "$out/"
    fi

    if [ -d ${extraModsDir} ]; then
      cp -a ${extraModsDir}/. "$out/"
    fi
  '';

  # ATM10 configuration is copied from the server pack and then amended with
  # settings for locally-added server mods.
  mergedConfig = pkgs.runCommand "atm10-7.3-merged-config" { } ''
    mkdir -p "$out"

    if [ -d ${modpack}/config ]; then
      cp -a ${modpack}/config/. "$out/"
    fi

    install -Dm644 ${pkgs.writeText "voicechat-server.properties" ''
      port=24454
      bind_address=0.0.0.0
      voice_chat_distance=48.0
      max_voice_distance=64.0
      keep_alive=1000
    ''} "$out/voicechat/voicechat-server.properties"
  '';
in
{
  # The Minecraft TCP port is handled by nix-minecraft's openFirewall option.
  # Simple Voice Chat uses UDP separately.
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

      # ATM10 is large; retain the existing memory envelope and Java 21/ZGC
      # tuning. NeoForge 1.21.1 requires Java 21.
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

      # mods is immutable/declarative and rebuilt from ATM10 + minecraft/mods.
      symlinks = {
        mods = mergedMods;
        "server-icon.png" = ../minecraft/server-icon.png;
      };

      # These trees are the pack-controlled server configuration. They are
      # refreshed when the Nix configuration changes.
      #
      # local/ is intentionally NOT managed here: ATM's own update guide treats
      # it as persistent server state to carry between pack versions.
      files = {
        config = mergedConfig;
        defaultconfigs = "${modpack}/defaultconfigs";
        kubejs = "${modpack}/kubejs";
        datapacks = "${modpack}/datapacks";
      };
    };
  };
}
