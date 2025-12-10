# generate containers from services
{ lib, config, inputs, ... }:
let
  cfg = config.stackpanel.secrets;
in {
  options.stackpanel.secrets = {
    enable = lib.mkEnableOption "secrets management via agenix";

    users = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          github = lib.mkOption { type = lib.types.str; };
          pubkey = lib.mkOption { type = lib.types.str; };
          admin = lib.mkOption { type = lib.types.bool; default = false; };
        };
      });
      default = {};
    };
    # ...
  };

  config = lib.mkIf cfg.enable {
    # Wire up agenix, generate secrets.nix, etc.
  };
}