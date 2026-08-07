{ ... }:

{
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  users.users.root = {
    openssh.authorizedKeys.keyFiles = [
      ../ssh/shulker.pub
    ];
  };
}
