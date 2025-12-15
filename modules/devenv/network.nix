# Step CA certificate management for devenv
#
# Usage in devenv.nix:
#   stackpanel.network.step = {
#     enable = true;
#     caUrl = "https://ca.internal:443";
#     caFingerprint = "...";
#   };
#
{ pkgs, lib, config, ... }:

let
  cfg = config.stackpanel.network.step;
  stateDir = "${config.stackpanel.stateDir}/step";

  # Import shared network library
  networkLib = import ../../lib/network.nix { inherit pkgs lib; };

  # Create scripts using shared library
  stepScripts = networkLib.mkStepScripts {
    inherit stateDir;
    inherit (cfg) caUrl caFingerprint provisioner certName;
  };

in {
  options.stackpanel.network.step = {
    enable = lib.mkEnableOption "Step CA certificate management";

    caUrl = lib.mkOption {
      type = lib.types.str;
      description = "Step CA URL (e.g., https://ca.internal:443)";
    };

    caFingerprint = lib.mkOption {
      type = lib.types.str;
      description = "Step CA root certificate fingerprint";
    };

    provisioner = lib.mkOption {
      type = lib.types.str;
      default = "Authentik";
      description = "Step CA provisioner name";
    };

    certName = lib.mkOption {
      type = lib.types.str;
      default = "device";
      description = "Common name for the device certificate";
    };
  };

  config = lib.mkIf cfg.enable {
    packages = stepScripts.allPackages;
  };
}
