{
  pkgs,
  inputs,
  lib,
  ...
}:

{
  system.stateVersion = "26.11";

  networking.hostName = "shulker-mc";

  powerManagement.cpuFreqGovernor = "performance";
  boot.kernelParams = [
    "mitigations=off"

    "nvme_core.default_ps_max_latency_us=0"

    "log_buf_len=20M"
  ];

  boot.kernelPackages = pkgs.linuxPackages_latest;

  boot.initrd.availableKernelModules = [
    "virtio"
    "virtio_pci"
    "virtio_ring"
    "virtio_blk"
    "virtio_scsi"
    "xfs"
    "ahci"
    "sd_mod"
    "sr_mod"
  ];

  boot.initrd.kernelModules = [
    "virtio_pci"
    "virtio_blk"
    "xfs"
  ];

  boot.kernelModules = [ "tcp_bbr" ];
  boot.kernel.sysctl = {
    "vm.swappiness" = 10;
    "vm.dirty_background_ratio" = 5;
    "vm.dirty_ratio" = 10;
    "vm.max_map_count" = 1048576;
    "vm.overcommit_memory" = 1;

    "net.core.default_qdisc" = "fq";
    "net.ipv4.tcp_congestion_control" = "bbr";
    "net.ipv4.tcp_fastopen" = 3;

    "net.core.somaxconn" = 8192;
    "net.core.netdev_max_backlog" = 16384;

    "net.core.rmem_max" = 16777216;
    "net.core.wmem_max" = 16777216;
    "net.ipv4.tcp_rmem" = "4096 87380 16777216";
    "net.ipv4.tcp_wmem" = "4096 65536 16777216";

    "net.ipv4.tcp_tw_reuse" = 1;
    "net.ipv4.tcp_fin_timeout" = 15;
  };

  services.udev.extraRules = ''
    ACTION=="add|change", KERNEL=="nvme[0-n]*", ATTR{queue/scheduler}="none"
  '';

  security.pam.loginLimits = [
    {
      domain = "*";
      item = "nofile";
      type = "soft";
      value = "524288";
    }
    {
      domain = "*";
      item = "nofile";
      type = "hard";
      value = "524288";
    }
  ];

  nix = {
    package = pkgs.lix;
    registry.s.flake = inputs.self;

    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
        "auto-allocate-uids"
      ];
      trusted-users = [
        "root"
        "@wheel"
      ];
      auto-optimise-store = true;
      fallback = true;
      keep-outputs = true;
      keep-derivations = true;
      connect-timeout = 5;
      http-connections = 32;
      always-allow-substitutes = true;
      builders-use-substitutes = true;
    };
  };

  nixpkgs.config = {
    allowUnfree = true;
  };

  # boot.initrd.systemd.enable = true;
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  programs.nix-ld.enable = true;
  services.envfs.enable = true;

  services.journald.extraConfig = "SystemMaxUse=200M";
  systemd.coredump.settings.Coredump.MaxUse = "200M";

  documentation.enable = false;
  documentation.man.enable = false;
  documentation.doc.enable = false;
  documentation.info.enable = false;
  documentation.dev.enable = false;
  documentation.nixos.enable = false;

  programs.command-not-found.enable = false;

  nix.channel.enable = false;

  programs.bash.completion.enable = false;

  services.getty.helpLine = lib.mkForce "";

  environment.systemPackages = with pkgs; [
    fastfetch
    nushell
    git
    git-lfs
    curl
    wget
    helix
    zellij
    gnumake
  ];
}
