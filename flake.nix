{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    bienenstock = {
      url = "github:oskardotglobal/bienenstock";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  nixConfig = {
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://deploy-rs.cachix.org"
      "https://cache.garnix.io"
    ];

    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "deploy-rs.cachix.org-1:xfNobmiwF/vzvK1gpfediPwpdIP0rpDV2rYqx40zdSI="
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
    ];
  };

  outputs =
    inputs@{
      bienenstock,
      sops-nix,
      ...
    }:
    bienenstock.mkFlake { inherit inputs; } (
      { lib, ... }:
      {
        imports = [
          bienenstock.flakeModules.default
          ./lib
        ];

        bienenstock = {
          modules = [ sops-nix.nixosModules.sops ];

          hosts = {
            demeter = {
              system = "aarch64-linux";
              modules = [ ./hosts/demeter/configuration.nix ];

              targetHost = "140.238.99.169";
            };

            persephone = {
              system = "aarch64-linux";
              modules = [ ./hosts/persephone/configuration.nix ];

              targetHost = "150.230.123.208";
              remoteBuild = true;
            };

            poseidon = {
              system = "aarch64-linux";
              modules = [ ./hosts/poseidon/configuration.nix ];

              targetHost = "129.159.86.137";
              remoteBuild = true;
            };
          };

          rootAuthorizedKeys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBsjQyPmsIUExmD++xE5YOEm9JBvw0iIjMkypWo7oFTa oskar@ares"
          ];
        };

        systems = [
          "x86_64-linux"
          "aarch64-linux"
        ];

        perSystem =
          { pkgs, ... }:
          {
            formatter = pkgs.nixfmt-tree;
            # devShells.default = import ./shell.nix { inherit pkgs; };

            checks = lib.mkForce { };
          };
      }
    );
}
