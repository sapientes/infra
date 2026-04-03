{
  pkgs,
  lib,
  bienenstockLib,
  ...
}:
{
  sops.secrets = {
    "pterodactyl-env" = { };
    "pterodactyl-mysql-password" = { };
    "pterodactyl-mysql-root-password" = { };
  };

  virtualisation.oci-containers.networks = [ "pterodactyl_default" ];

  virtualisation.oci-containers.containers."pterodactyl-cache" = {
    image = "redis:alpine";
    log-driver = "journald";
    extraOptions = [
      "--network-alias=cache"
    ];

    restartAlways = true;
    networks = [ "pterodactyl_default" ];
  };

  virtualisation.oci-containers.containers."pterodactyl-database" = {
    image = "library/mysql:8.0";
    environment = {
      MYSQL_DATABASE = "panel";
      MYSQL_PASSWORD_FILE = "/run/secrets/mysql-password";
      MYSQL_ROOT_PASSWORD_FILE = "/run/secrets/mysql-root-password";
      MYSQL_USER = "pterodactyl";
    };
    volumes = [
      "/var/lib/pterodactyl/mysql:/var/lib/mysql:rw"
      "/run/secrets/pterodactyl-mysql-password:/run/secrets/mysql-password:ro"
      "/run/secrets/pterodactyl-mysql-root-password:/run/secrets/mysql-root-password:ro"
    ];
    cmd = [ "--default-authentication-plugin=mysql_native_password" ];
    log-driver = "journald";
    extraOptions = [
      "--network-alias=database"
    ];

    restartAlways = true;
    networks = [ "pterodactyl_default" ];
  };

  virtualisation.oci-containers.containers."pterodactyl-panel" =
    let
      nix2container = bienenstockLib.nix2container."${pkgs.system}";

      imageName = "pelican-dev/panel";
      imageTag = "v1.0.0-beta";

      configs = pkgs.runCommand "pterodactyl-image" { } ''
        mkdir -p $out/etc/caddy
        cat > $out/etc/caddy/Caddyfile <<- EOM
        {
          admin off
        }

        :80 {
          root * /var/www/html/public
          encode gzip

          php_fastcgi 127.0.0.1:9000
          file_server
        }
        EOM

        mkdir -p $out/etc/service/{php-fpm,queue-worker,supercronic,caddy}/supervise

        cat > $out/etc/service/php-fpm/run <<- 'EOM'
        #!/bin/sh
        exec /usr/local/sbin/php-fpm -F
        EOM

        cat > $out/etc/service/queue-worker/run <<- 'EOM'
        #!/bin/sh
        exec su-exec www-data /usr/local/bin/php /var/www/html/artisan queue:work --tries=3
        EOM

        cat > $out/etc/service/caddy/run <<- 'EOM'
        #!/bin/sh
        exec su-exec www-data caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
        EOM

        cat > $out/etc/service/supercronic/run <<- 'EOM'
        #!/bin/sh
        exec su-exec www-data supercronic -overlapping /etc/supercronic/crontab
        EOM

        cat > $out/entrypoint.sh <<- EOM
        #!/bin/ash
        cd /var/www/html

        rm -f .env
        cat /pelican-data/.env > .env

        chown -R www-data:www-data .

        ## make sure the db is set up
        echo -e "Migrating Database"
        php artisan migrate --force

        echo -e "Optimizing Filament"
        php artisan filament:optimize

        exec runsvdir -P /etc/service
        EOM
      '';

      image = nix2container.buildImage {
        name = imageName;
        tag = imageTag;

        # v1.0.0-beta28
        fromImage = nix2container.pullImage {
          imageName = "ghcr.io/${imageName}";
          imageDigest = "sha256:9d58d20726ab4cecd713c21eef0cc26c69a1d2a9223e9d59921c37751b22b7ad";
          arch = "arm64";
          sha256 = "sha256-Rnv003aUMhrMZyV6xCIM2GhNmBHnKRvmSu79KC8i5Cg=";
        };

        config.entrypoint = [ "/entrypoint.sh" ];

        perms = [
          {
            path = configs;
            regex = "/etc/service(/.*)?";
            mode = "0644";
          }
          {
            path = configs;
            regex = "/entrypoint\.sh|/etc/service(/.*/run)?";
            mode = "0755";
          }
        ];

        copyToRoot = [
          pkgs.runit
          pkgs.su-exec
          configs
        ];
      };

      imageFile = pkgs.runCommand "pterodactyl-image-file" { } ''
        ${lib.getExe image.copyTo} --tmpdir . "docker-archive:$out:${imageName}:${imageTag}"
      '';
    in
    {
      inherit imageFile;
      image = "${imageName}:${imageTag}";

      volumes = [ "/run/secrets/pterodactyl-env:/pelican-data/.env" ];
      environment = { };

      labels = {
        "traefik.docker.network" = "pterodactyl_default";
        "traefik.enable" = "true";
        "traefik.http.routers.pterodactyl.entrypoints" = "websecure";
        "traefik.http.routers.pterodactyl.rule" = "Host(`panel.sapientes.ovh`) || Host(`panel.ligma.ovh`)";
        "traefik.http.routers.pterodactyl.service" = "pterodactyl";
        "traefik.http.routers.pterodactyl.tls" = "true";
        "traefik.http.routers.pterodactyl.tls.certresolver" = "letsencrypt";
        "traefik.http.services.pterodactyl.loadbalancer.server.port" = "80";
      };
      dependsOn = [
        "pterodactyl-cache"
        "pterodactyl-database"
      ];
      log-driver = "journald";
      extraOptions = [
        "--network-alias=panel"
        "--user=root"
      ];

      restartAlways = true;
      networks = [ "pterodactyl_default" ];
    };
}
