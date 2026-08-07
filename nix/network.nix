{ ... }:

{
  networking = {
    useDHCP = false;
    useNetworkd = true;
    usePredictableInterfaceNames = true;

    hostName = "shulker";
    domain = "fyi";
  };

  systemd.network = {
    enable = true;

    links."10-eth0" = {
      matchConfig.MACAddress = "bc:24:11:6f:87:16";
      linkConfig.Name = "eth0";
    };

    networks."20-eth0" = {
      matchConfig.MACAddress = "bc:24:11:6f:87:16";

      address = [
        "82.22.77.40/24"
        "2a10:4646:2ec:0:be24:11ff:fe6f:8716/64"
      ];

      routes = [
        {
          Destination = "0.0.0.0/0";
          Gateway = "82.22.77.1";
          GatewayOnLink = true;
        }
        {
          Destination = "::/0";
          Gateway = "fe80::21c:73ff:fec7:c557";
        }
      ];

      networkConfig = {
        DNS = [
          "2620:fe::10"
          "9.9.9.10"
        ];

        IPv6AcceptRA = false;
      };
    };
  };
}
