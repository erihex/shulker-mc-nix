{ ... }:

{
  networking.useDHCP = false;

  systemd.network = {
    enable = true;

    links = {
      "10-eth0" = {
        matchConfig.MACAddress = "bc:24:11:f0:32:57";
        linkConfig.Name = "eth0";
      };

      "10-eth1" = {
        matchConfig.MACAddress = "bc:24:11:41:7b:1f";
        linkConfig.Name = "eth1";
      };
    };

    networks = {
      "20-eth0" = {
        matchConfig.MACAddress = "bc:24:11:f0:32:57";

        address = [
          "82.22.77.40/24"
        ];

        routes = [
          {
            Destination = "0.0.0.0/0";
            Gateway = "82.22.77.1";
          }
        ];

        networkConfig = {
          DNS = [
            "1.1.1.1"
          ];

          IPv6AcceptRA = false;
        };
      };

      "20-eth1" = {
        matchConfig.MACAddress = "bc:24:11:41:7b:1f";

        address = [
          "2a10:4646:2ec::1b5/48"
        ];

        routes = [
          {
            Destination = "::/0";
            Gateway = "2a10:4646:2e0::1";
            GatewayOnLink = true;
          }
        ];

        networkConfig = {
          DNS = [
            "1.1.1.1"
          ];

          IPv6AcceptRA = false;
        };
      };
    };
  };
}
