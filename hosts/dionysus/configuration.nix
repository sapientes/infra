{
  imports = [
    ../../lib/nixosModules/traefik.nix
    ../../lib/nixosModules/wings.nix
    ../../lib/nixosModules/substituters.nix

    ./hardware-configuration.nix
  ];

  services.wings = {
    enable = true;

    enableTraefik = true;
    openFirewall = true;
    domain = "dionysus.ligma.ovh";

    secretConfigFile = "/run/secrets/wings.yml";
    configuration = {
      debug = false;
      system.data = "/var/lib/pelican/volumes";
      docker.network.dns = [ "169.254.169.254" ];
      remote = "https://panel.ligma.ovh";
    };
  };

  sops = {
    defaultSopsFile = ./secrets.yaml;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    secrets."wings.yml" = { };
  };

  networking = {
    networkmanager.enable = true;

    firewall = {
      enable = true;
      allowedTCPPorts = [ 25565 ];
      allowedUDPPorts = [ 25565 ];
    };
  };

  boot.loader.grub.configurationLimit = 1;
  system.stateVersion = "25.11";
}
