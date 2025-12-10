# Secrets exec command - run commands with decrypted secrets as env vars
# Similar to: sops exec-env secrets.yaml 'command'
#
# Usage:
#   nix run .#secrets-exec -- 'echo $API_KEY'
#   nix run .#secrets-exec -- ./my-script.sh
#
{ lib, flake-parts-lib, inputs, ... }:
let
  inherit (flake-parts-lib) mkPerSystemOption;
in {
  options.perSystem = mkPerSystemOption ({ config, pkgs, system, ... }:
  let
    cfg = config.stackpanel.secrets;
    
    # Get agenix CLI
    agenix = inputs.agenix.packages.${system}.default;
    
    # Convert secret filename to env var name
    # api-key.age -> API_KEY
    # db-password.age -> DB_PASSWORD
    secretToEnvName = filename:
      let
        # Remove .age extension
        base = lib.removeSuffix ".age" filename;
        # Replace - and . with _
        cleaned = builtins.replaceStrings ["-" "."] ["_" "_"] base;
        # Uppercase
      in lib.toUpper cleaned;

    # Script that decrypts all secrets and runs command
    secretsExecScript = pkgs.writeShellScriptBin "stackpanel-secrets-exec" ''
      set -euo pipefail
      
      SECRETS_DIR="${cfg.secretsDir}"
      AGENIX="${agenix}/bin/agenix"
      
      if [[ $# -eq 0 ]]; then
        echo "Usage: secrets-exec <command>"
        echo ""
        echo "Decrypts all secrets in $SECRETS_DIR and runs <command> with them as env vars."
        echo ""
        echo "Secret files are converted to env var names:"
        echo "  api-key.age    -> API_KEY"
        echo "  db-password.age -> DB_PASSWORD"
        echo ""
        echo "Available secrets:"
        for f in "$SECRETS_DIR"/*.age; do
          if [[ -f "$f" ]]; then
            basename "$f"
          fi
        done
        exit 1
      fi
      
      # Check for SSH key
      if [[ ! -f ~/.ssh/id_ed25519 ]] && [[ ! -f ~/.ssh/id_rsa ]]; then
        echo "Warning: No SSH key found. You may not be able to decrypt secrets."
      fi
      
      # Build environment with decrypted secrets
      for secret_file in "$SECRETS_DIR"/*.age; do
        if [[ -f "$secret_file" ]]; then
          filename=$(basename "$secret_file")
          # Convert to env var name: api-key.age -> API_KEY
          env_name=$(echo "''${filename%.age}" | tr '[:lower:]-.' '[:upper:]__')
          
          echo "Decrypting: $filename -> $env_name" >&2
          
          # Decrypt and capture value
          if value=$("$AGENIX" -d "$secret_file" 2>/dev/null); then
            export "$env_name=$value"
          else
            echo "Warning: Failed to decrypt $filename (you may not have access)" >&2
          fi
        fi
      done
      
      echo "" >&2
      echo "Running: $*" >&2
      echo "---" >&2
      
      # Run the command
      exec "$@"
    '';

    # Script to edit secrets (wrapper around agenix -e)
    secretsEditScript = pkgs.writeShellScriptBin "stackpanel-secrets-edit" ''
      set -euo pipefail
      
      SECRETS_DIR="${cfg.secretsDir}"
      AGENIX="${agenix}/bin/agenix"
      
      if [[ $# -eq 0 ]]; then
        echo "Usage: secrets-edit <secret-name>"
        echo ""
        echo "Edit or create a secret. Opens \$EDITOR with decrypted content."
        echo ""
        echo "Examples:"
        echo "  secrets-edit api-key        # Edits secrets/api-key.age"
        echo "  secrets-edit db-password    # Edits secrets/db-password.age"
        echo ""
        echo "Existing secrets:"
        for f in "$SECRETS_DIR"/*.age; do
          if [[ -f "$f" ]]; then
            basename "''${f%.age}"
          fi
        done
        exit 1
      fi
      
      SECRET_NAME="$1"
      SECRET_FILE="$SECRETS_DIR/$SECRET_NAME.age"
      
      # Ensure secrets dir exists
      mkdir -p "$SECRETS_DIR"
      
      # Check if secret is defined in secrets.nix
      if [[ -f "$SECRETS_DIR/secrets.nix" ]] && ! grep -q "\"$SECRET_NAME.age\"" "$SECRETS_DIR/secrets.nix"; then
        echo "Warning: $SECRET_NAME.age not defined in secrets.nix"
        echo "Add it to your flake.nix first:"
        echo ""
        echo "  stackpanel.secrets.secrets.\"$SECRET_NAME.age\".owners = [ \"your-username\" ];"
        echo ""
        echo "Then run: nix run .#generate"
        exit 1
      fi
      
      cd "$SECRETS_DIR"
      exec "$AGENIX" -e "$SECRET_NAME.age"
    '';

    # Script to list secrets and show who has access
    secretsListScript = pkgs.writeShellScriptBin "stackpanel-secrets-list" ''
      set -euo pipefail
      
      SECRETS_DIR="${cfg.secretsDir}"
      
      echo "Secrets in $SECRETS_DIR:"
      echo ""
      
      for f in "$SECRETS_DIR"/*.age; do
        if [[ -f "$f" ]]; then
          filename=$(basename "$f")
          env_name=$(echo "''${filename%.age}" | tr '[:lower:]-.' '[:upper:]__')
          echo "  $filename -> \$$env_name"
        fi
      done
      
      echo ""
      echo "Use 'nix run .#secrets-exec -- <command>' to run with secrets loaded"
      echo "Use 'nix run .#secrets-edit <name>' to edit a secret"
    '';

  in {
    options.stackpanel.secrets.secretsDir = lib.mkOption {
      type = lib.types.str;
      default = "secrets";
      description = "Directory containing .age secret files";
    };

    config = lib.mkIf cfg.enable {
      packages = {
        secrets-exec = secretsExecScript;
        secrets-edit = secretsEditScript;
        secrets-list = secretsListScript;
      };
    };
  });
}
