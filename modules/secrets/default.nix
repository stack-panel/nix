# Secrets module - SOPS-based secrets management
#
# Uses standard SOPS workflow:
#   sops secrets/dev.yaml
#   sops secrets/production.yaml
#   sops exec-env secrets/dev.yaml './my-script.sh'
#
{ ... }: {
  imports = [
    ./sops.nix
  ];
}
