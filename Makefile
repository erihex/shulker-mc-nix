HOST ?= shulker-mc

.PHONY: switch test check update install clean

switch:
	sudo nixos-rebuild switch --flake path:.#$(HOST)

test:
	sudo nixos-rebuild dry-activate --flake path:.#$(HOST)

check:
	nix flake check path:.

update:
	nix flake update

install:
	sudo nix run github:nix-community/disko/latest -- \
		--mode destroy,format,mount ./nix/disko.nix
	sudo nixos-install --flake path:.#$(HOST)

clean:
	sudo nix-env --profile /nix/var/nix/profiles/system --delete-generations +3
	sudo nix-store --gc
	nix-store --optimise
