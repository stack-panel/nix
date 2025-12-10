# Secrets module
{ ... }: {
  imports = [
    ./users.nix
    ./exec.nix
  ];
}