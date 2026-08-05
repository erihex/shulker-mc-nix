{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/vda";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              priority = 1;
              name = "ESP";
              size = "1024M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [
                  "defaults"
                  "umask=0077"
                ];
              };
            };

            nix = {
              priority = 2;
              name = "nix";
              size = "100G";
              content = {
                type = "filesystem";
                format = "xfs";
                mountpoint = "/nix";
                mountOptions = [
                  "defaults"
                  "noatime"
                  "logbufs=8"
                  "logbsize=256k"
                  "allocsize=64M"
                ];
              };
            };

            root = {
              priority = 3;
              name = "root";
              size = "100%";
              content = {
                type = "filesystem";
                format = "xfs";
                mountpoint = "/";
                mountOptions = [
                  "defaults"
                  "noatime"
                  "logbufs=8"
                  "logbsize=256k"
                  "allocsize=64M"
                ];
              };
            };
          };
        };
      };
    };
  };
}
