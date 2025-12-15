# Re-export devenv.nix for direct Nix imports
# (devenv.yaml uses devenv.nix directly, but flake imports need default.nix)
import ./devenv.nix
