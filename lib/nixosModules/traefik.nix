{
  virtualisation = {
    docker = {
      enable = true;
      autoPrune.enable = true;

      # OCI seems to block any other DNS servers other than this one
      daemon.settings.dns = [ "169.254.169.254" ];
    };

    oci-containers.backend = "docker";
  };

  services.traefik = {
    enable = true;
    group = "docker";

    staticConfigOptions = {
      providers.docker = {
        endpoint = "unix:///var/run/docker.sock";
        exposedByDefault = false;
        network = "traefik";
      };

      entryPoints = {
        web = {
          address = ":80";
          http.redirections.entryPoint = {
            to = "websecure";
            scheme = "https";
          };
        };

        websecure = {
          address = ":443";
        };
      };

      certificatesResolvers.letsencrypt.acme = {
        email = "me@oskar.global";
        storage = "/var/lib/traefik/acme.json";
        tlsChallenge = { };
      };
    };
  };

  networking.firewall = {
    allowedTCPPorts = [
      80
      443
    ];
    allowedUDPPorts = [
      80
      443
    ];
  };
}
