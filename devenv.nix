{ pkgs, lib, config, inputs, ... }:

{
  imports = [
    ./modules/devenv/default.nix
    ./modules/devenv/theme.nix
  ];
  stackpanel.theme = {
    enable = true;
  };

  enterShell = ''
    echo "Entering stackpanel development environment"
  '';
}
