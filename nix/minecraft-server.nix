{ pkgs, ... }:

let
  modpackExtracted = pkgs.runCommand "integrated-mc-unpacked" {
    nativeBuildInputs = [ pkgs.unzip ];
  } ''
    mkdir -p $out
    unzip ${../minecraft/Integrated_Minecraft-1.6.8_server_pack.zip} -d $out
  '';
in
{
  networking.firewall.allowedTCPPorts = [ 25565 ];
  networking.firewall.allowedUDPPorts = [ 24454 ];

  services.minecraft-servers = {
    enable = true;
    eula = true;

    servers = {
      shulker = {
        enable = true;

        package = pkgs.forgeServers.forge-1_20_1;
        jvmPackage = pkgs.corretto21;

        jvmOpts = builtins.concatStringsSep " " [
          "-Xms4G"
          "-Xmx10G"
          "-XX:+UseZGC"
          "-XX:+ZGenerational"
          "-XX:+AlwaysPreTouch"
          "-XX:+ParallelRefProcEnabled"
          "-XX:+DisableExplicitGC"
        ];

        serverProperties = {
          server-port = 25565;
          gamemode = "survival";
          difficulty = "medium";
          motd = "§cч§6а§eт§aи§bк§d, §cа§6б§eо§aб§bа";
          max-players = 42;
          online-mode = false;
          white-list = false;
          enable-rcon = false;
          enforce-secure-profile = false;
        };

        symlinks = {
          "mods" = "${modpackExtracted}/mods";
          "config" = "${modpackExtracted}/config";
          "defaultconfigs" = "${modpackExtracted}/defaultconfigs";
          "kubejs" = "${modpackExtracted}/kubejs";
          "server-icon.png" = "${modpackExtracted}/server-icon.png";
          
          "mods/whitelistgate.jar" = ../minecraft/mods/whitelistgate-1.0.0-forge-1.20.1.jar;
          "mods/voicechat.jar" = ../minecraft/mods/voicechat-forge-1.20.1-2.6.21.jar;
          "mods/authmod.jar" = ../minecraft/mods/authmod-1.0.0.jar;
        };

        files = {
          "config/whitelistgate.json" = builtins.toJSON {
            enabled = true;
          };

          "config/voicechat/voicechat-server.properties" = ''
            port=24454
            bind_address=0.0.0.0
            voice_chat_distance=48.0
            max_voice_distance=64.0
            keep_alive=1000
          '';

          "ops.json" = builtins.toJSON [
            {
              uuid = "2f240b6b-aef7-35aa-917f-952faeb3f8bc";
              name = "eri";
              level = 4;
              bypassesPlayerLimit = true;
            }
          ];
        };
      };
    };
  };
}