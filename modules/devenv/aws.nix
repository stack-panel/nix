# AWS cert-auth for devenv
#
# Usage in devenv.nix:
#   stackpanel.aws.certAuth = {
#     enable = true;
#     accountId = "123456789";
#     ...
#   };
#
{ pkgs, lib, config, ... }:

let
  cfg = config.stackpanel.aws.certAuth;
  stateDir = "${config.stackpanel.stateDir}/aws";

  certPath = "${stateDir}/device-root.chain.crt";
  keyPath = "${stateDir}/device.key";
  cacheFile = "${stateDir}/.aws-creds-cache.json";

  awsCredsEnv = pkgs.writeShellScriptBin "aws-creds-env" ''
    set -euo pipefail

    fetch_fresh_creds() {
      ${pkgs.aws-signing-helper}/bin/aws_signing_helper credential-process \
        --certificate "${certPath}" \
        --private-key "${keyPath}" \
        --role-arn "arn:aws:iam::${cfg.accountId}:role/${cfg.roleName}" \
        --trust-anchor-arn "${cfg.trustAnchorArn}" \
        --profile-arn "${cfg.profileArn}"
    }

    use_cache=false
    if [[ -f "${cacheFile}" ]]; then
      expiration=$(${pkgs.jq}/bin/jq -r '.Expiration // empty' "${cacheFile}" 2>/dev/null || true)
      if [[ -n "$expiration" ]]; then
        if exp_epoch=$(date -d "$expiration" +%s 2>/dev/null) || \
           exp_epoch=$(date -jf "%Y-%m-%dT%H:%M:%SZ" "$expiration" +%s 2>/dev/null); then
          now_epoch=$(date +%s)
          if (( exp_epoch - now_epoch > ${cfg.cacheBufferSeconds} )); then
            use_cache=true
          fi
        fi
      fi
    fi

    if $use_cache; then
      creds=$(cat "${cacheFile}")
    else
      creds=$(fetch_fresh_creds)
      mkdir -p "$(dirname "${cacheFile}")"
      echo "$creds" > "${cacheFile}"
      chmod 600 "${cacheFile}"
    fi

    echo "AWS_ACCESS_KEY_ID=$(echo "$creds" | ${pkgs.jq}/bin/jq -r '.AccessKeyId')"
    echo "AWS_SECRET_ACCESS_KEY=$(echo "$creds" | ${pkgs.jq}/bin/jq -r '.SecretAccessKey')"
    echo "AWS_SESSION_TOKEN=$(echo "$creds" | ${pkgs.jq}/bin/jq -r '.SessionToken')"
    echo "AWS_REGION=${cfg.region}"
  '';

  awsCli = pkgs.writeShellScriptBin "aws" ''
    eval "$(${awsCredsEnv}/bin/aws-creds-env)"
    exec ${pkgs.awscli2}/bin/aws "$@"
  '';

in {
  options.stackpanel.aws.certAuth = {
    enable = lib.mkEnableOption "AWS Roles Anywhere cert auth";

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
    packages = [
      pkgs.aws-signing-helper
      awsCli
      awsCredsEnv
      pkgs.chamber
    ];

    env.AWS_REGION = cfg.region;
  };
}
