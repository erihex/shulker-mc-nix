{
  pkgs,
  lib,
  ...
}:

let
  forgeServer = pkgs.callPackage ./forge-server.nix {
    jre = pkgs.corretto17;
  };

  modpackExtracted =
    pkgs.runCommand "integrated-mc-unpacked"
      {
        nativeBuildInputs = [
          pkgs.unzip
        ];
      }
      ''
        mkdir -p "$out"

        unzip \
          ${../minecraft/Integrated_Minecraft-1.6.8_server_pack.zip} \
          -d "$out"
      '';

  # Additional server-side mods placed into the final mods directory.
  #
  # The attribute name becomes the destination filename.
  extraMods = {
    "whitelistgate.jar" = ../minecraft/mods/whitelistgate-1.0.0-forge-1.20.1.jar;

    "voicechat.jar" = ../minecraft/mods/voicechat-forge-1.20.1-2.6.21.jar;

    "authmod.jar" = ../minecraft/mods/authmod-1.0.0.jar;
  };

  # Mods bundled in the pack that must not run on the dedicated server.
  #
  # These values are passed to `find -name`, so wildcard patterns are
  # supported.
  excludedServerMods = [
    "CrashAssistant-*.jar"
    "alltheleaks-*.jar"
  ];

  # Additional declarative files overlaid onto the modpack's config
  # directory.
  #
  # Paths are relative to config/.
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

    # Add more configuration files like this:
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
        install -Dm644 \
          ${source} \
          "$out/${destination}"
      '') files
    );

  removeExcludedMods = lib.concatMapStringsSep "\n" (pattern: ''
    find "$out" \
      -maxdepth 1 \
      -type f \
      -name ${lib.escapeShellArg pattern} \
      -print \
      -delete
  '') excludedServerMods;

  mergedMods = pkgs.runCommand "integrated-mc-merged-mods" { } ''
    mkdir -p "$out"

    if [ -d ${modpackExtracted}/mods ]; then
      cp -r \
        ${modpackExtracted}/mods/. \
        "$out/"
    fi

    ${removeExcludedMods}

    ${copyFiles extraMods}

    if find "$out" \
      -maxdepth 1 \
      -type f \
      -iname '*crashassistant*' |
      grep -q .
    then
      echo "Crash Assistant was not removed from the server mod set" >&2
      exit 1
    fi
  '';

  mergedConfig = pkgs.runCommand "integrated-mc-merged-config" { } ''
    mkdir -p "$out"

    if [ -d ${modpackExtracted}/config ]; then
      cp -r \
        ${modpackExtracted}/config/. \
        "$out/"
    fi

    ${copyFiles extraConfigFiles}
  '';
in
{
  networking.firewall = {
    allowedTCPPorts = [
      25565
    ];

    allowedUDPPorts = [
      24454
    ];
  };

  services.minecraft-servers = {
    enable = true;
    eula = true;

    servers.shulker = {
      enable = true;
      autoStart = true;

      package = forgeServer;

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

        "server-icon.png" = ../minecraft/server-icon.png;
      };

      files = {
        "config" = mergedConfig;

        "defaultconfigs" = "${modpackExtracted}/defaultconfigs";

        "kubejs" = "${modpackExtracted}/kubejs";
      };
    };
  };
}
