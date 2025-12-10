{
  description = "stackpanel";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    devenv.url = "github:cachix/devenv";
    agenix.url = "github:ryantm/agenix";
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        # Import our own modules for dogfooding/testing
        ./modules
      ];
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
      
      perSystem = { config, self', inputs', pkgs, system, ... }: 
      let
        # Import team data from .stackpanel/ (written by agent)
        teamData = import ./.stackpanel/team.nix;
      in {
        # ══════════════════════════════════════════════════════════════
        # TEST CONFIG - this is how consumers will use stackpanel
        # ══════════════════════════════════════════════════════════════
        stackpanel = {
          # Team synced from GitHub by agent
          secrets = {
            enable = true;
            users = teamData.users;
            secrets = {
              "api-key.age".owners = [ "alice" "bob" ];
              "db-password.age".owners = [ "alice" ];
              "stripe-key.age".owners = [ "alice" "bob" "charlie" ];
            };
            rekey.enable = true;
          };
          
          # CI
          ci.github = {
            enable = true;
            checks = {
              enable = true;
              commands = [ "nix flake check" ];
            };
          };
        };
      };
      
      flake = {
        # The usual flake attributes can be defined here, including system-
        # agnostic ones like nixosModule and system-enumerating ones, although
        # those are more easily expressed in perSystem.
        # Individual modules for granular imports
        flakeModules = {
          default = ./modules;
          core = ./modules/core;
          secrets = ./modules/secrets;
          devenv = ./modules/devenv;
          ci = ./modules/ci;
          vscode = ./modules/vscode;
          network = ./modules/network;
        };
        
        # Templates for `nix flake init`
        templates.default = {
          path = ./templates/default;
          description = "stackpanel project template";
        };
      };
    };
}
