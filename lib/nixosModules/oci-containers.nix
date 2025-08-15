{
  pkgs,
  lib,
  config,
  ...
}:
with lib;
let
  cfg = config.virtualisation.oci-containers;
  backendCmd = getExe pkgs."${cfg.backend}";
in
{
  options.virtualisation.oci-containers = {
    networks = mkOption {
      type = types.listOf types.str;
      default = [ ];
    };

    containers = mkOption {
      type = types.attrsOf (
        types.submodule {
          options.restartAlways = mkEnableOption "restarting the container on errors and system restart";
        }
      );
    };
  };

  config.systemd.services =
    let
      networks =
        cfg.networks
        |> map (name: {
          name = "${cfg.backend}-network-${name}";
          value = {
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              ExecStop = "${backendCmd} network rm -f '${name}'";
            };

            script = ''
              ${backendCmd} network inspect '${name}' \
                || ${backendCmd} network create '${name}'
            '';
          };
        });

      containers =
        cfg.containers
        |> mapAttrsToList (
          name:
          {
            networks ? [ ],
            restartAlways ? false,
            ...
          }:
          let
            networks' = map (v: "${cfg.backend}-network-${v}.service") networks;
          in
          {
            name = "${cfg.backend}-${name}";

            value = {
              serviceConfig = mkIf restartAlways {
                Restart = mkOverride 500 "always";
                RestartMaxDelaySec = mkOverride 500 "1m";
                RestartSec = mkOverride 500 "100ms";
                RestartSteps = mkOverride 500 9;
              };

              after = networks';
              requires = networks';
            };
          }
        );
    in
    listToAttrs (networks ++ containers);
}
