{ inputs, ... }:
{
  flake.bienenstockLib.packages.nix2container =
    { system, ... }: inputs.nix2container.packages."${system}".nix2container;
}
