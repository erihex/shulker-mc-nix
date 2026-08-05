HOST ?= shulker-mc

.PHONY: switch test update install clean

switch:
	sudo nixos-rebuild switch --flake .#$(HOST) --extra-experimental-features "nix-command flakes"

test:
	sudo nixos-rebuild dry-activate --flake .#$(HOST) --extra-experimental-features "nix-command flakes"

update:
	nix --experimental-features "nix-command flakes" flake update

install:
	sudo nix --experimental-features "nix-command flakes" run \
		github:nix-community/disko/latest -- \
		--mode destroy,format,mount ./nix/disko.nix
	sudo nixos-install --flake path:.#$(HOST)

clean:
	sudo nix-env --profile /nix/var/nix/profiles/system --delete-generations +3
	sudo nix-store --gc
	nix-store --optimise
