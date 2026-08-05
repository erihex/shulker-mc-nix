{ ... }:

{
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  users.users.root = {
    openssh.authorizedKeys.keyFiles = [
      ../ssh/shulker.pub
    ];
  };
}
