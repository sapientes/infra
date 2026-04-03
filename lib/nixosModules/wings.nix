{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.services.wings;

  wings = pkgs.buildGoModule {
    pname = "wings";
    version = "1.0.0-beta24";

    src = pkgs.fetchFromGitHub {
      owner = "pelican-dev";
      repo = "wings";
      rev = "v1.0.0-beta24";
      sha256 = "sha256-MveNLXINvxAjJOG9nvXgfSxnEUkHI0Bnqxmgg/0Qu6Q=";
    };

    vendorHash = "sha256-juiJGX0wax1iIAODAgBUNLlfFg4kd14bB6IeEqohs8U=";

    env.CGO_ENABLED = "0";

    ldflags = [
      "-s"
      "-w"
      "-X github.com/pelican-dev/wings/system.Version=1.0.0-beta24"
    ];

    meta.mainProgram = "wings";
  };
in
{
  options.services.wings = {
    enable = mkEnableOption "Pelican Wings daemon";
    enableTraefik = mkEnableOption "Traefik reverse proxy configuration for Wings";

    openFirewall = mkEnableOption "firewall rules for Wings";

    domain = mkOption { type = types.str; };
    configFile = mkOption { type = types.path; };

    apiPort = mkOption {
      type = types.port;
      default = 8080;
      description = "Port Wings listens on. Must match api.port in config.yml. Only used when enableTraefik is true.";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.wings = {
      description = "Pelican Wings Daemon";
      after = [ "docker.service" ];
      requires = [ "docker.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        User = "root";
        WorkingDirectory = "/etc/pelican";
        LimitNOFILE = 4096;
        ExecStartPre = pkgs.writeShellScript "wings-pre" ''
          mkdir -p /etc/pelican /var/lib/pelican /var/log/pelican/install /tmp/pelican
          cat ${cfg.configFile} > /etc/pelican/config.yml
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
