{ modulesPath, ... }:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  fileSystems."/" = {
    device = "/dev/sda1";
    fsType = "ext4";
  };

  boot.loader = {
    grub = {
      enable = true;
      devices = [ "/dev/sda" ];
    };

    timeout = 30;
  };

  boot.initrd.availableKernelModules = [
    "ata_piix"
    "uhci_hcd"
    "xen_blkfront"
  ];

  boot.initrd.kernelModules = [
    "nvme"
  ];

  boot.tmp.cleanOnBoot = true;
  zramSwap.enable = true;
}
