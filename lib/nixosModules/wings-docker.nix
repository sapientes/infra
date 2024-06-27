{
  pkgs,
  lib,
  config,
  ...
}:
with lib;
let
  cfg = config.services.wings-docker;
in
{
  options.services.wings-docker = {
    enable = mkEnableOption "wings-docker service";
    enableTraefik = mkEnableOption "wings-docker service traefik config";

    openFirewall = mkEnableOption "wings-docker service firewall config";

    domain = mkOption { type = types.str; };
    configFile = mkOption { type = types.str; };
  };

  config =
    let
      target = "docker-wings-root.target";
    in
    mkIf cfg.enable {
      virtualisation.oci-containers.containers.wings = {
        image = "ghcr.io/pelican-dev/wings:v1.0.0-beta13";

        environment = {
          TZ = "UTC";
          WINGS_DOMAIN = cfg.domain;
          WINGS_GID = "988";
          WINGS_UID = "988";
          WINGS_USERNAME = "pelican";
        };

        volumes = [
          "/var/run/docker.sock:/var/run/docker.sock:rw"
          "/var/lib/docker/containers:/var/lib/docker/containers:rw"
          "/var/lib/pelican:/var/lib/pelican:rw"
          "/etc/pelican:/etc/pelican:rw"
          "/tmp/pelican:/tmp/pelican:rw"
          "/var/log/pelican:/var/log/pelican:rw"
        ];

        ports =
          let
            ports = [ "2022:2022/tcp" ] ++ lib.optional (!cfg.enableTraefik) "443:443/tcp";
          in
          if cfg.openFirewall then ports else map (port: "127.0.0.1:${port}") ports;

        labels = mkIf cfg.enableTraefik {
          "traefik.docker.network" = "pelican_nw";
          "traefik.enable" = "true";
          "traefik.http.routers.wings.entrypoints" = "websecure";
          "traefik.http.routers.wings.rule" = "Host(`${cfg.domain}`)";
          "traefik.http.routers.wings.service" = "wings";
          "traefik.http.routers.wings.tls" = "true";
          "traefik.http.routers.wings.tls.certresolver" = "letsencrypt";
          "traefik.http.services.wings.loadbalancer.server.port" = "443";
        };

        log-driver = "journald";

        extraOptions = [
          "--network-alias=wings"
          "--network=pelican_nw"
        ];
      };

      systemd.services."docker-wings" = {
        serviceConfig = {
          Restart = lib.mkOverride 500 "always";
          RestartMaxDelaySec = lib.mkOverride 500 "1m";
          RestartSec = lib.mkOverride 500 "100ms";
          RestartSteps = lib.mkOverride 500 9;
        };

        after = [ "docker-network-pelican_nw.service" ];
        requires = [ "docker-network-pelican_nw.service" ];
        partOf = [ target ];
        wantedBy = [ target ];
      };

      systemd.services."docker-network-pelican_nw" = {
        path = [ pkgs.docker ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStop = "${pkgs.docker}/bin/docker network rm -f pelican_nw";
        };
        script = ''
          docker network inspect pelican_nw \
            || docker network create pelican_nw \
              --driver=bridge \
              --opt=com.docker.network.bridge.name=pelican_nw \
              --subnet=172.21.0.0/16
          mkdir -p /etc/pelican
          cat ${cfg.configFile} > /etc/pelican/config.yml
        '';

        partOf = [ target ];
        wantedBy = [ target ];
      };

      systemd.targets."docker-wings-root" = {
        unitConfig = {
          Description = "Root target generated from wings-docker.";
        };
        wantedBy = [ "multi-user.target" ];
      };

      networking.firewall = mkIf cfg.openFirewall {
        allowedTCPPorts = [ 2022 ] ++ lib.optional (!cfg.enableTraefik) 443;
      };
    };
}
