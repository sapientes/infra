{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.services.wings;

  wings = pkgs.callPackage ../../packages/pelican-wings.nix { };
in
{
  options.services.wings = {
    enable = mkEnableOption "Pelican Wings daemon";
    enableTraefik = mkEnableOption "Traefik reverse proxy configuration for Wings";

    openFirewall = mkEnableOption "firewall rules for Wings";

    domain = mkOption { type = types.str; };

    configuration = mkOption {
      type = types.attrs;
      default = { };
      description = "Base Wings configuration written to the Nix store at eval time. Merged with secretConfigFile at runtime, with secrets taking precedence.";
    };

    secretConfigFile = mkOption {
      type = types.path;
      description = "Path to a YAML file containing secret configuration values. Merged on top of configuration at runtime.";
    };

    apiPort = mkOption {
      type = types.port;
      default = 8080;
      description = "Port Wings listens on. Must match api.port in config.yml. Only used when enableTraefik is true.";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.wings =
      let
        autoConfig = recursiveUpdate
          { system.sftp.bind_port = 2022; }
          (optionalAttrs cfg.enableTraefik {
            api = {
              host = "0.0.0.0";
              port = cfg.apiPort;
              ssl.enabled = false;
            };
          });
        storeConfig = (pkgs.formats.yaml { }).generate "wings-config.yml"
          (recursiveUpdate autoConfig cfg.configuration);
      in
      {
        description = "Pelican Wings Daemon";
        after = [ "docker.service" ];
        requires = [ "docker.service" ];
        wantedBy = [ "multi-user.target" ];

        path = [
          pkgs.shadow
          pkgs.yq-go
        ];

        serviceConfig = {
          User = "root";
          WorkingDirectory = "/etc/pelican";
          LimitNOFILE = 4096;
          ExecStartPre = pkgs.writeShellScript "wings-pre" ''
            mkdir -p /etc/pelican /var/lib/pelican /var/log/pelican/install /tmp/pelican
            yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' \
              ${storeConfig} ${cfg.secretConfigFile} > /etc/pelican/config.yml
          '';
          ExecStart = "${lib.getExe wings} --config /etc/pelican/config.yml";
          Restart = "on-failure";
          RestartSec = "5s";
          StartLimitIntervalSec = 180;
          StartLimitBurst = 30;
        };
      };

    services.traefik.dynamicConfigOptions = mkIf cfg.enableTraefik {
      http = {
        routers.wings = {
          entryPoints = [ "websecure" ];
          rule = "Host(`${cfg.domain}`)";
          service = "wings";
          tls.certResolver = "letsencrypt";
        };

        services.wings.loadBalancer = {
          passHostHeader = true;
          servers = [ { url = "http://127.0.0.1:${toString cfg.apiPort}"; } ];
        };
      };
    };

    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [ 2022 ] ++ lib.optional (!cfg.enableTraefik) cfg.apiPort;
    };
  };
}
