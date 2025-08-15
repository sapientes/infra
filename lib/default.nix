{
  imports = [ ./nix2container.nix ];
  flake.bienenstockLib.modulesPath = ./nixosModules;
}
