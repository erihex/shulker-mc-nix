{
  pkgs,
  inputs,
  lib,
  ...
}:

let
  modpackExtracted =
    pkgs.runCommand "integrated-mc-unpacked"
      {
        nativeBuildInputs = [ pkgs.unzip ];
      }
      ''
        mkdir -p "$out"

        unzip \
          ${../minecraft/Integrated_Minecraft-1.6.8_server_pack.zip} \
          -d "$out"
      '';

  extraMods = {
    "whitelistgate.jar" = ../minecraft/mods/whitelistgate-1.0.0-forge-1.20.1.jar;

    "voicechat.jar" = ../minecraft/mods/voicechat-forge-1.20.1-2.6.21.jar;

    "authmod.jar" = ../minecraft/mods/authmod-1.0.0.jar;
  };

  extraConfigFiles = {
    "whitelistgate.json" = pkgs.writeText "whitelistgate.json" (
      builtins.toJSON {
        enabled = true;
      }
    );

    "voicechat/voicechat-server.properties" = pkgs.writeText "voicechat-server.properties" ''
      port=24454
      bind_address=0.0.0.0
      voice_chat_distance=48.0
      max_voice_distance=64.0
      keep_alive=1000
    '';

    # Add more configuration files here.
    #
    # Example:
    #
    # "some-mod/settings.toml" =
    #   pkgs.writeText "some-mod-settings.toml" ''
    #     enabled = true
    #   '';
  };

  copyFiles =
    files:
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (destination: source: ''
        install -Dm644 ${source} "$out/${destination}"
      '') files
    );

  mergedMods = pkgs.runCommand "integrated-mc-merged-mods" { } ''
    mkdir -p "$out"

    if [ -d ${modpackExtracted}/mods ]; then
      cp -r ${modpackExtracted}/mods/. "$out/"
    fi

    ${copyFiles extraMods}
  '';

  mergedConfig = pkgs.runCommand "integrated-mc-merged-config" { } ''
    mkdir -p "$out"

    if [ -d ${modpackExtracted}/config ]; then
      cp -r ${modpackExtracted}/config/. "$out/"
    fi

    ${copyFiles extraConfigFiles}
  '';
in
{
  networking.firewall.allowedTCPPorts = [
    25565
  ];

  networking.firewall.allowedUDPPorts = [
    24454
  ];

  services.minecraft-servers = {
    enable = true;
    eula = true;

    servers.shulker = {
      enable = true;
      autoStart = true;

      package =
        inputs.nix-minecraft-forge.legacyPackages."x86_64-linux".forgeServers.forge-1_20_1.override
          {
            jre = pkgs.corretto17;
          };

      jvmOpts = builtins.concatStringsSep " " [
        "-Xms8G"
        "-Xmx12G"
        "-XX:+UseZGC"
      ];

      serverProperties = {
        server-port = 25565;
        server-ip = "";

        gamemode = "survival";
        difficulty = "medium";
        motd = "§cч§6а§eт§aи§bк§d, §cа§6б§eо§aб§bа";

        max-players = 42;

        online-mode = false;
        white-list = false;
        enable-rcon = false;
        enforce-secure-profile = false;
      };

      operators = {
        eri = {
          uuid = "2f240b6b-aef7-35aa-917f-952faeb3f8bc";
          level = 4;
          bypassesPlayerLimit = true;
        };
      };

      symlinks = {
        "mods" = mergedMods;
        "server-icon.png" = "${modpackExtracted}/server-icon.png";
      };

      files = {
        "config" = mergedConfig;

        "defaultconfigs" = "${modpackExtracted}/defaultconfigs";

        "kubejs" = "${modpackExtracted}/kubejs";
      };
    };
  };
}
