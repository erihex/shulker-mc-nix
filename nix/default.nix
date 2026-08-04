{ ... }:

{
  imports = [
    ./minecraft-server.nix
    ./system-tuning.nix
    ./backup.nix
  ];
}