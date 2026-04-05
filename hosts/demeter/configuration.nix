{
  imports = [
    ../../lib/nixosModules/traefik.nix
    ../../lib/nixosModules/wings.nix
    ../../lib/nixosModules/substituters.nix

    ./hardware-configuration.nix
  ];

  services = {
    wings = {
      enable = true;

      enableTraefik = true;
      openFirewall = true;
      domain = "demeter.ligma.ovh";

      secretConfigFile = "/run/secrets/wings.yml";
      configuration = {
        debug = false;
        system.data = "/var/lib/pelican/volumes";
        docker.network.dns = [ "169.254.169.254" ];
        remote = "https://panel.ligma.ovh";
      };
    };

    netbird.enable = true;
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
      allowedTCPPorts = [
        25565
        7777
        2759
      ];
      allowedUDPPorts = [
        25565
        7777
        2759
      ];
    };
  };

  boot.loader.grub.configurationLimit = 1;
  system.stateVersion = "24.11";
}
