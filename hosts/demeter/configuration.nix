{
  imports = [
    ../../lib/nixosModules/traefik.nix
    ../../lib/nixosModules/wings-docker.nix
    ../../lib/nixosModules/substituters.nix

    ./hardware-configuration.nix
  ];

  services = {
    wings-docker = {
      enable = true;
      enableTraefik = true;
      openFirewall = true;
      domain = "demeter.ligma.ovh";
      configFile = "/run/secrets/wings.yml";
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
      ];
      allowedUDPPorts = [
        25565
        7777
      ];
    };
  };

  boot.loader.grub.configurationLimit = 1;
  system.stateVersion = "24.11";
}
