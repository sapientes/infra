{
  imports = [
    ../../lib/nixosModules/traefik.nix
    ../../lib/nixosModules/oci-containers.nix
    ../../lib/nixosModules/wings.nix
    ../../lib/nixosModules/pelican.nix
    ../../lib/nixosModules/substituters.nix

    ./hardware-configuration.nix
  ];

  services = {
    wings = {
      enable = true;

      enableTraefik = true;
      openFirewall = true;
      domain = "poseidon.ligma.ovh";

      secretConfigFile = "/run/secrets/wings.yml";
      configuration = {
        debug = false;
        system.data = "/var/lib/pelican/volumes";
        docker.network.dns = [ "169.254.169.254" ];
        remote = "https://panel.ligma.ovh";
      };
    };

    pelican = {
      enable = true;

      enableTraefik = true;
      domain = "panel.ligma.ovh";

      secretEnvFile = "/run/secrets/pelican-env";
      configuration = {
        APP_NAME = "Ligma Inc. Game Server Panel";
        OAUTH_GITHUB_ENABLED = true;
        OAUTH_GITHUB_SHOULD_CREATE_MISSING_USERS = true;
        OAUTH_GITHUB_SHOULD_LINK_MISSING_USERS = true;
      };
    };

    caddy = {
      enable = true;

      globalConfig = ''
        auto_https off
        admin off
      '';
    };
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
