{ ... }:

{
  imports = [
    ./minecraft-server.nix
    ./system-tuning.nix
    ./backup.nix
    ./ssh.nix
    ./hardware.nix
    ./network.nix
  ];
}
