# Utility functions for stackpanel modules
{ lib, pkgs }:
{
  # Convert attrs to YAML using nixpkgs yaml format
  toYAML = attrs:
    let
      yaml = pkgs.formats.yaml {};
    in builtins.readFile (yaml.generate "output.yml" attrs);
}
