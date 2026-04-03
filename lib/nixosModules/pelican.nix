{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.services.pelican;

  php = pkgs.php84.withExtensions (
    { enabled, all }:
    with all;
    enabled
    ++ [
      intl
      zip
    ]
  );

  panel = pkgs.callPackage ../../packages/pelican-panel.nix { inherit php; };

  setupScript = pkgs.writeShellScript "pelican-setup" ''
    set -euo pipefail

    STATE=/var/lib/pelican
    WWW=$STATE/www
    STORE=${panel}

    # Create persistent state directories
    mkdir -p \
      $STATE/storage/{app/public,framework/{cache/data,sessions,views},logs/install} \
      $STATE/plugins \
      $STATE/bootstrap-cache

    # Rebuild the working webroot when the panel package changes
    if [ "$(cat $WWW/.nix-store-path 2>/dev/null || true)" != "$STORE" ]; then
      rm -rf "$WWW"
      cp -r "$STORE" "$WWW"
      chmod -R u+w "$WWW"
      echo "$STORE" > "$WWW/.nix-store-path"
    fi

    # Writable overlay symlinks
    rm -rf  "$WWW/storage"          && ln -sfn $STATE/storage         "$WWW/storage"
    rm -rf  "$WWW/bootstrap/cache"  && ln -sfn $STATE/bootstrap-cache "$WWW/bootstrap/cache"
    rm -rf  "$WWW/plugins"          && ln -sfn $STATE/plugins         "$WWW/plugins"
    ln -sfn $STATE/storage/app/public "$WWW/public/storage"
    ln -sfn ${cfg.configFile}          "$WWW/.env"

    # Make public assets readable by caddy
    chmod -R o+rX "$WWW/public"

    chown -R pelican:pelican $STATE

    # Run migrations and cache optimizations as the pelican user
    cd "$WWW"
    ${pkgs.sudo}/bin/sudo -u pelican ${php}/bin/php artisan migrate --force
    ${pkgs.sudo}/bin/sudo -u pelican ${php}/bin/php artisan filament:optimize
  '';
in
{
  options.services.pelican = {
    enable = mkEnableOption "Pelican Panel";
    enableTraefik = mkEnableOption "Traefik reverse proxy configuration for Pelican";

    openFirewall = mkEnableOption "firewall rules for Pelican";

    domain = mkOption { type = types.str; };
    configFile = mkOption { type = types.path; };

    apiPort = mkOption {
      type = types.port;
      default = 8081;
    };

  };

  config = mkIf cfg.enable {
    users = {
      users.pelican = {
        isSystemUser = true;
        group = "pelican";
        home = "/var/lib/pelican";
      };
      groups.pelican = { };
    };

    services = {

      mysql = {
        enable = true;
        package = pkgs.mysql80;
      };

      redis.servers.pelican = {
        enable = true;
        bind = "127.0.0.1";
        port = 6379;
      };

      phpfpm.pools.pelican = {
        phpPackage = php;
        user = "pelican";
        group = "pelican";

        settings = {
          "listen" = "127.0.0.1:9000";
          "pm" = "dynamic";
          "pm.max_children" = 10;
          "pm.start_servers" = 2;
          "pm.min_spare_servers" = 2;
          "pm.max_spare_servers" = 5;
          "chdir" = "/var/lib/pelican/www";
          "catch_workers_output" = "yes";
          "decorate_workers_output" = "no";
          "env[LOG_CHANNEL]" = "stderr";
        };

        phpOptions = ''
          opcache.enable=1
          opcache.memory_consumption=128
          opcache.interned_strings_buffer=8
          opcache.max_accelerated_files=10000
          opcache.validate_timestamps=0
        '';
      };

      caddy = {
        enable = true;

        globalConfig = ''
          auto_https off
          admin off
        '';

        virtualHosts.":${toString cfg.apiPort}" = {
          extraConfig = ''
            root * /var/lib/pelican/www/public
            encode gzip
            file_server
            php_fastcgi 127.0.0.1:9000
          '';
        };
      };

      traefik.dynamicConfigOptions = mkIf cfg.enableTraefik {
        http = {
          routers.pelican = {
            entryPoints = [ "websecure" ];
            rule = "Host(`${cfg.domain}`)";
            service = "pelican";
            tls.certResolver = "letsencrypt";
          };

          services.pelican.loadBalancer = {
            passHostHeader = true;
            servers = [ { url = "http://127.0.0.1:${toString cfg.apiPort}"; } ];
          };
        };
      };
    };

    systemd = {
      services = {
        phpfpm-pelican = {
          after = [ "pelican-setup.service" ];
          requires = [ "pelican-setup.service" ];
        };

        caddy = {
          after = [ "pelican-setup.service" ];
          requires = [ "pelican-setup.service" ];
        };

        pelican-setup = {
          description = "Pelican Panel Setup";
          wantedBy = [ "multi-user.target" ];
          after = [
            "mysql.service"
            "redis-pelican.service"
          ];
          requires = [
            "mysql.service"
            "redis-pelican.service"
          ];
          before = [
            "phpfpm-pelican.service"
            "caddy.service"
            "pelican-queue.service"
          ];

          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = setupScript;
          };
        };

        pelican-queue = {
          description = "Pelican Panel Queue Worker";
          after = [ "pelican-setup.service" ];
          requires = [ "pelican-setup.service" ];
          wantedBy = [ "multi-user.target" ];

          serviceConfig = {
            User = "pelican";
            Group = "pelican";
            WorkingDirectory = "/var/lib/pelican/www";
            ExecStart = "${php}/bin/php artisan queue:work --tries=3";
            Restart = "on-failure";
            RestartSec = "5s";
          };
        };

        pelican-scheduler = {
          description = "Pelican Panel Scheduler";
          after = [ "pelican-setup.service" ];

          serviceConfig = {
            Type = "oneshot";
            User = "pelican";
            Group = "pelican";
            WorkingDirectory = "/var/lib/pelican/www";
            ExecStart = "${php}/bin/php artisan schedule:run";
          };
        };
      };

      timers.pelican-scheduler = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "*-*-* *:*:00";
          Persistent = true;
        };
      };
    };

    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = lib.optional (!cfg.enableTraefik) cfg.apiPort;
    };
  };
}
