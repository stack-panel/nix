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

  # Import shared AWS library
  awsLib = import ../../lib/aws.nix { inherit pkgs lib; };

  # Create scripts using shared library
  awsScripts = awsLib.mkAwsCredScripts {
    inherit stateDir;
    inherit (cfg) accountId roleName trustAnchorArn profileArn region cacheBufferSeconds;
  };

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
    packages = awsScripts.allPackages;
    env = awsScripts.env;
  };
}
