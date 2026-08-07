{
  disko.devices = {
    disk.main = {
      type = "disk";
      device = "/dev/sda";

      content = {
        type = "gpt";

        partitions = {
          bios = {
            priority = 1;
            name = "bios";
            size = "4M";
            type = "EF02";
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
                "noatime"
              ];
            };
          };
        };
      };
    };
  };
}
