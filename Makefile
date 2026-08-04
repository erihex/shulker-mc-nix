HOST ?= $(shell hostname)
DISK ?= /dev/disk/by-id/ata-QEMU_DVD-ROM_QM00001

.PHONY: switch test format update install clean

switch: format
	sudo nixos-rebuild switch --flake .#$(HOST) --extra-experimental-features "nix-command flakes"

test: format
	sudo nixos-rebuild dry-activate --flake .#$(HOST) --extra-experimental-features "nix-command flakes"

# format:
# 	nix fmt --extra-experimental-features "nix-command flakes"

update:
	nix --experimental-features "nix-command flakes" flake update

install:
	sudo nix --experimental-features "nix-command flakes" run \
		github:nix-community/disko/latest -- \
		--mode destroy,format,mount ./nix/disko.nix
	sudo nixos-install --flake .#$(HOST) --extra-experimental-features "nix-command flakes"

clean:
	sudo nix-env --profile /nix/var/nix/profiles/system --delete-generations +3
	sudo nix-store --gc
	nix-store --optimise
