{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    nix-minecraft = {
      url = "github:Infinidoge/nix-minecraft";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # disko = {
    #   url = "github:nix-community/disko";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };
  };

  outputs =
    {
      self,
      nixpkgs,
      nix-minecraft,
      disko,
      microvm,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
    in
    {
      nixosConfigurations = {
        shulker-mc = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };

          modules = [
            # disko.nixosModules.disko
            nix-minecraft.nixosModules.minecraft-servers

            {
              nixpkgs.overlays = [ nix-minecraft.overlay ];
            }

            ./nix
          ];
        };
      };
    };
}
