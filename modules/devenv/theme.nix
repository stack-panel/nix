{ pkgs, lib, config, ... }:
let
  cfg = config.stackpanel.theme;
in {
  options.stackpanel.theme = {
    enable = pkgs.lib.mkEnableOption "Starship prompt for stackpanel devenv";
  };
  config = lib.mkIf cfg.enable {
    packages = [
      pkgs.starship
    ];
    enterShell = ''
      # syntax: bash
      export STARSHIP_CONFIG=$DEVENV_STATE/starship.toml
      install -m 644 ${./starship.toml} $DEVENV_STATE/starship.toml

      eval "$(starship init $SHELL)"
  '';
  };
}