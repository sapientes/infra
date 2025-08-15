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
      inherit (bienenstockLib.packages pkgs) nix2container;

      imageName = "pelican-dev/panel";
      imageTag = "v1.0.0-beta22";

      image = nix2container.buildImage {
        name = imageName;
        tag = "${imageTag}+custom";

        fromImage = nix2container.pullImage {
          imageName = "ghcr.io/${imageName}";
          imageDigest = "sha256:3982d746bff5f6623c476804d71b2445e4cd6c2205b3dbb205e4e5414d6fda21";
          arch = "arm64";
          sha256 = "sha256-ZuuSJPh2s8dPVR6EJ/bdbdwgMeLCB2Vtk3pxsWWpF1g=";
        };

        config.entrypoint = [
          "/bin/ash"
          "/entrypoint.sh"
        ];

        copyToRoot = pkgs.runCommand "pterodactyl-image" { } ''
          mkdir -p $out/var/www/html/config
          cat > $out/var/www/html/config/logging.php <<- EOM
          <?php

          return [
            'default' => [
              'driver' => 'monolog',
              'handler' => Monolog\Handler\StreamHandler::class,
              'handler_with' => ['stream' => 'php://stdout'],
              'level' => env('LOG_LEVEL', 'info'),
            ],
          ];
          EOM

          mkdir -p $out/etc/caddy
          cat > $out/etc/caddy/Caddyfile <<- EOM
          :80 {
            root * /var/www/html/public
            encode gzip

            php_fastcgi 127.0.0.1:9000
            file_server
          }
          EOM

          cat > $out/entrypoint.sh <<- EOM
          #!/bin/ash
          chown www-data:www-data .
          exec sudo -u www-data /bin/ash docker/entrypoint.sh
          EOM
        '';
      };

      imageFile = pkgs.runCommand "pterodactyl-image-file" { } ''
        ${lib.getExe image.copyTo} --tmpdir . docker-archive:$out
      '';
    in
    {
      inherit imageFile;
      image = "${imageName}:${imageTag}+custom";

      volumes = [ "/run/secrets/pterodactyl-env:/pelican-data/.env" ];

      labels = {
        "traefik.docker.network" = "pterodactyl_default";
        "traefik.enable" = "true";
        "traefik.http.routers.pterodactyl.entrypoints" = "websecure";
        "traefik.http.routers.pterodactyl.rule" = "Host(`panel.sapientes.ovh`)";
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
