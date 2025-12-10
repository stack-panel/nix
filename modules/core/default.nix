# Core module - base options and file generation system
{ ... }: {
  imports = [
    ./options.nix
    ./generate.nix
    ./datadir.nix
  ];
}
