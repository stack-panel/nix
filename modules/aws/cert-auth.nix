# AWS Roles Anywhere certificate-based authentication
#
# Provides:
#   - aws-creds-env: outputs AWS credentials as env vars
#   - aws: wrapper that auto-injects credentials
#
{ config, pkgs, lib, ... }:
let
  cfg = config.stackpanel.aws.cert-auth;
  stateDir = config.stackpanel.stateDir;

  # Derived paths (computed from cfg)
  certPath = "${cfg.stateDir}/device-root.chain.crt";
  keyPath = "${cfg.stateDir}/device.key";
  cacheFile = "${cfg.stateDir}/.aws-creds-cache.json";

  # Outputs AWS credentials as env vars (for eval or docker)
  awsCredsEnv = pkgs.writeShellScriptBin "aws-creds-env" ''
    # bash
    set -euo pipefail

    CERT_PATH="${certPath}"
    KEY_PATH="${keyPath}"
    CACHE_FILE="${cacheFile}"
    CACHE_BUFFER="${cfg.cacheBufferSeconds}"

    fetch_fresh_creds() {
      ${pkgs.aws-signing-helper}/bin/aws_signing_helper credential-process \
        --certificate "$CERT_PATH" \
        --private-key "$KEY_PATH" \
        --role-arn "arn:aws:iam::${cfg.accountId}:role/${cfg.roleName}" \
        --trust-anchor-arn "${cfg.trustAnchorArn}" \
        --profile-arn "${cfg.profileArn}"
    }

    use_cache=false
    if [[ -f "$CACHE_FILE" ]]; then
      expiration=$(${pkgs.jq}/bin/jq -r '.Expiration // empty' "$CACHE_FILE" 2>/dev/null || true)
      if [[ -n "$expiration" ]]; then
        # Parse ISO8601 timestamp (works on both Linux and macOS)
        if exp_epoch=$(date -d "$expiration" +%s 2>/dev/null) || \
           exp_epoch=$(date -jf "%Y-%m-%dT%H:%M:%SZ" "$expiration" +%s 2>/dev/null); then
          now_epoch=$(date +%s)
          if (( exp_epoch - now_epoch > CACHE_BUFFER )); then
            use_cache=true
          fi
        fi
      fi
    fi

    if $use_cache; then
      creds=$(cat "$CACHE_FILE")
    else
      creds=$(fetch_fresh_creds)
      mkdir -p "$(dirname "$CACHE_FILE")"
      echo "$creds" > "$CACHE_FILE"
      chmod 600 "$CACHE_FILE"
    fi

    echo "AWS_ACCESS_KEY_ID=$(echo "$creds" | ${pkgs.jq}/bin/jq -r '.AccessKeyId')"
    echo "AWS_SECRET_ACCESS_KEY=$(echo "$creds" | ${pkgs.jq}/bin/jq -r '.SecretAccessKey')"
    echo "AWS_SESSION_TOKEN=$(echo "$creds" | ${pkgs.jq}/bin/jq -r '.SessionToken')"
    echo "AWS_REGION=${cfg.region}"
  '';

  # Wrapper for aws CLI that auto-injects credentials
  awsCli = pkgs.writeShellScriptBin "aws" ''
    eval "$(${awsCredsEnv}/bin/aws-creds-env)"
    exec ${pkgs.awscli2}/bin/aws "$@"
  '';
in {
  options.stackpanel.aws.cert-auth = {
    enable = lib.mkEnableOption "AWS Roles Anywhere cert auth";

    stateDir = lib.mkOption {
      type = lib.types.str;
      description = "Directory for certs, keys, and credential cache";
    };

    region = lib.mkOption {
      type = lib.types.str;
      default = "us-west-2";
      description = "AWS region";
    };

    accountId = lib.mkOption {
      type = lib.types.str;
      description = "AWS account ID";
    };

    roleName = lib.mkOption {
      type = lib.types.str;
      description = "IAM role name to assume";
    };

    trustAnchorArn = lib.mkOption {
      type = lib.types.str;
      description = "AWS Roles Anywhere trust anchor ARN";
    };

    profileArn = lib.mkOption {
      type = lib.types.str;
      description = "AWS Roles Anywhere profile ARN";
    };

    cacheBufferSeconds = lib.mkOption {
      type = lib.types.str;
      default = "300";
      description = "Seconds before expiry to refresh cached credentials";
    };
  };

  config = lib.mkIf cfg.enable {
    # Default stateDir derived from global stateDir
    stackpanel.aws.cert-auth.stateDir = lib.mkOptionDefault "${stateDir}/aws";

    stackpanel.packages = [
      pkgs.aws-signing-helper
      awsCli
      awsCredsEnv
      pkgs.chamber
    ];

    stackpanel.env = {
      AWS_REGION = cfg.region;
    };
  };
}