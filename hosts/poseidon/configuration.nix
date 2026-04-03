{
  imports = [
    ../../lib/nixosModules/traefik.nix
    ../../lib/nixosModules/oci-containers.nix
    ../../lib/nixosModules/wings.nix
    ../../lib/nixosModules/pelican.nix
    ../../lib/nixosModules/substituters.nix

    ./hardware-configuration.nix
  ];

  services.wings = {
    enable = true;
    enableTraefik = true;
    openFirewall = true;
    domain = "poseidon.ligma.ovh";
    configFile = "/run/secrets/wings.yml";
  };

  services.pelican = {
    enable = true;
    enableTraefik = true;
    openFirewall = false;
    domain = "panel.ligma.ovh";
    configFile = "/run/secrets/pelican-env";
  };

  sops = {
    defaultSopsFile = ./secrets.yaml;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    secrets = {
      "wings.yml" = { };
      "pelican-env".owner = "pelican";
    };
  };

  networking = {
    networkmanager.enable = true;

    firewall = {
      enable = true;
      allowedTCPPorts = [
        8192
        25565
      ];
      allowedUDPPorts = [
        8192
        25565
      ];
    };
  };

  boot.loader.grub.configurationLimit = 1;
  system.stateVersion = "24.05";
}
