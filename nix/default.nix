{ ... }:

{
  imports = [
    ./minecraft-server.nix
    ./system-tuning.nix
    ./backup.nix
    ./ssh.nix
    ./disko.nix
  ];
}