{ pkgs, ... }: {
  packages = [
    pkgs.starship
  ];

  enterShell = ''
    export STARSHIP_CONFIG=$DEVENV_STATE/starship.toml
    install -m 644 ${./starship.toml} $DEVENV_STATE/starship.toml

    eval "$(starship init $SHELL)"
  '';
}