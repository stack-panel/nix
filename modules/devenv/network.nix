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

  certPath = "${stateDir}/device-root.chain.crt";
  keyPath = "${stateDir}/device.key";

  caHost = lib.removePrefix "https://" (lib.removeSuffix ":443" cfg.caUrl);

  checkCert = pkgs.writeShellScriptBin "check-device-cert" ''
    set -uo pipefail

    red='\033[0;31m'
    green='\033[0;32m'
    nc='\033[0m'

    pass() { echo -e "''${green}OK''${nc}"; }
    fail() { echo -e "''${red}FAIL''${nc}"; }

    all_passed=true

    echo -n "Checking if CA is reachable... "
    if ${pkgs.netcat}/bin/nc -z -w 3 "${caHost}" 443 2>/dev/null; then
      pass
    else
      fail
      echo "  Hint: Is Tailscale connected?"
      all_passed=false
    fi

    echo -n "Checking if root cert is installed... "
    if [[ -f "$HOME/.step/certs/root_ca.crt" ]]; then
      pass
    else
      fail
      echo "  Hint: Run 'ensure-device-cert' to bootstrap"
      all_passed=false
    fi

    echo -n "Checking if fingerprint matches... "
    if actual_fp=$(${pkgs.step-cli}/bin/step ca roots --ca-url="${cfg.caUrl}" 2>/dev/null | \
       ${pkgs.step-cli}/bin/step certificate fingerprint 2>/dev/null); then
      if [[ "$actual_fp" == "${cfg.caFingerprint}" ]]; then
        pass
      else
        fail
        echo "  Expected: ${cfg.caFingerprint}"
        echo "  Got:      $actual_fp"
        all_passed=false
      fi
    else
      fail
      echo "  Hint: Could not reach CA to verify fingerprint"
      all_passed=false
    fi

    echo -n "Checking if device certificate exists... "
    if [[ -f "${certPath}" && -f "${keyPath}" ]]; then
      pass
    else
      fail
      echo "  Hint: Run 'ensure-device-cert' to generate"
      all_passed=false
    fi

    if [[ -f "${certPath}" ]]; then
      echo -n "Checking if device certificate is valid... "
      if ${pkgs.step-cli}/bin/step certificate verify "${certPath}" --roots="$HOME/.step/certs/root_ca.crt" 2>/dev/null; then
        pass
      else
        fail
        echo "  Hint: Certificate may be expired or invalid"
        all_passed=false
      fi
    fi

    echo ""
    if $all_passed; then
      echo -e "''${green}All checks passed!''${nc}"
      exit 0
    else
      echo -e "''${red}Some checks failed.''${nc}"
      exit 1
    fi
  '';

  ensureCert = pkgs.writeShellScriptBin "ensure-device-cert" ''
    set -euo pipefail

    if [[ -f "${certPath}" && -f "${keyPath}" ]]; then
      echo "Device certificate already exists at ${certPath}"
      exit 0
    fi

    echo "Setting up device certificate..."
    mkdir -p "${stateDir}"

    if [[ ! -f "$HOME/.step/certs/root_ca.crt" ]]; then
      echo "Bootstrapping CA trust..."
      ${pkgs.step-cli}/bin/step ca bootstrap \
        --ca-url "${cfg.caUrl}" \
        --fingerprint "${cfg.caFingerprint}" \
        --install
    else
      echo "CA already bootstrapped, skipping..."
    fi

    echo "Verifying CA fingerprint..."
    actual_fingerprint=$(${pkgs.step-cli}/bin/step ca roots --ca-url="${cfg.caUrl}" | \
      ${pkgs.step-cli}/bin/step certificate fingerprint)
    if [[ "$actual_fingerprint" != "${cfg.caFingerprint}" ]]; then
      echo "ERROR: CA fingerprint mismatch!"
      echo "  Expected: ${cfg.caFingerprint}"
      echo "  Got:      $actual_fingerprint"
      exit 1
    fi
    echo "CA fingerprint verified."

    echo "Requesting device certificate..."
    device_cert="${stateDir}/device.crt"
    ${pkgs.step-cli}/bin/step ca certificate \
      "${cfg.certName}" \
      "$device_cert" \
      "${keyPath}" \
      --provisioner="${cfg.provisioner}" \
      --ca-url="${cfg.caUrl}"

    echo "Fetching root CA certificate..."
    root_cert="${stateDir}/root_ca.crt"
    ${pkgs.step-cli}/bin/step ca roots \
      "$root_cert" \
      --ca-url="${cfg.caUrl}"

    echo "Assembling certificate chain..."
    cat "$device_cert" "$root_cert" > "${certPath}"

    chmod 600 "${keyPath}"
    chmod 644 "${certPath}"

    echo "Device certificate chain created at ${certPath}"
  '';

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
    packages = [
      ensureCert
      checkCert
      pkgs.step-cli
    ];
  };
}
