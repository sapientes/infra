{
  pkgs ? import <nixpkgs> { },
  ...
}:
pkgs.mkShell {
  nativeBuildInputs = with pkgs; [
    just
    sops
    deploy-rs
  ];
}
