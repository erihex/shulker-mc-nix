{
  inputs = {
    nixpkgs = {
      url = "github:NixOS/nixpkgs/nixos-unstable";
    };

    nix-minecraft = {
      url = "github:Infinidoge/nix-minecraft";
    };

    disko = {
      url = "github:nix-community/disko";
    };
  };

  outputs = { nixpkgs, nix-minecraft, disko, ... }:
  
  let
    system = "x86_64-linux";
  in
  {
    formatter.${system} = nixpkgs.legacyPackages.${system}.alejandra;

    nixosConfigurations = {
      shulker-mc = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          disko.nixosModules.disko
          nix-minecraft.nixosModules.minecraft-servers
          {
            nixpkgs.overlays = [ nix-minecraft.overlays.default ];
          }
          ./nix
        ];
      };
    };
  };
}