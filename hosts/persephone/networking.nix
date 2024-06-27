{
  networking.hostName = "persephone";
  networking.networkmanager.enable = true;

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      80
      443
      25565
    ];
    allowedUDPPorts = [
      80
      443
      25565
    ];
  };

  # OCI seems to block any other DNS servers other than this one
  virtualisation.docker.daemon.settings.dns = [ "169.254.169.254" ];
}
