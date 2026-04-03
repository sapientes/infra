{ inputs, config, ... }:
{
  flake.bienenstockLib.nix2container =
    config.systems
    |> map (system: {
      name = system;
      value = inputs.nix2container.packages."${system}".nix2container;
    })
    |> builtins.listToAttrs;
}
