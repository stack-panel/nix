{
  description = "stackpanel - composable Nix modules for full-stack projects";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  nixConfig = {
    extra-trusted-public-keys = "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=";
    extra-substituters = "https://devenv.cachix.org";
  };

  outputs = inputs@{ flake-parts, nixpkgs, self, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        # Import stackpanel flake-parts wrapper for this flake's own use
        ./modules/flake-parts.nix
      ];

      systems = [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ];

      perSystem = { config, pkgs, system, ... }: {
        # Development shell for working on stackpanel itself
        devShells.default = pkgs.mkShell {
          packages = [ pkgs.nil pkgs.nixfmt-classic ];
        };
      };

      flake = {
        # ════════════════════════════════════════════════════════════════════
        # STANDALONE MODULES (Primary - no flake-parts dependency)
        #
        # For use with lib.evalModules, NixOS configurations, or custom
        # module systems. These are pure NixOS-style modules.
        #
        # Usage with lib.evalModules:
        #   let
        #     result = lib.evalModules {
        #       modules = [
        #         inputs.stackpanel.nixosModules.default
        #         { config.stackpanel.enable = true; }
        #         { config._module.args.pkgs = pkgs; }
        #       ];
        #     };
        #   in result.config.stackpanel.packages
        #
        # Or import individual modules:
        #   modules = [
        #     inputs.stackpanel.nixosModules.core
        #     inputs.stackpanel.nixosModules.aws
        #   ];
        # ════════════════════════════════════════════════════════════════════
        nixosModules = {
          default = ./modules;
          core = ./modules/core;
          secrets = ./modules/secrets;
          ci = ./modules/ci;
          network = ./modules/network;
          aws = ./modules/aws;
          theme = ./modules/theme;
          container = ./modules/container;
        };

        # ════════════════════════════════════════════════════════════════════
        # FLAKE-PARTS INTEGRATION (Secondary - for flake-parts users)
        #
        # For flake-parts users (flake.nix):
        #   imports = [ inputs.stackpanel.flakeModules.default ];
        #
        #   perSystem = { pkgs, ... }: {
        #     stackpanel.aws.certAuth = { enable = true; ... };
        #   };
        # ════════════════════════════════════════════════════════════════════
        flakeModules = {
          default = ./modules/flake-parts.nix;
        };

        # ════════════════════════════════════════════════════════════════════
        # DEVENV MODULES (for devenv.yaml users)
        #
        # For devenv.yaml users (no flake.nix):
        #   inputs:
        #     stackpanel:
        #       url: github:darkmatter/stackpanel/nix
        #   imports:
        #     - stackpanel/devenvModules/default
        #
        # Or import individual modules:
        #   imports:
        #     - stackpanel/devenvModules/aws
        #     - stackpanel/devenvModules/network
        # ════════════════════════════════════════════════════════════════════
        devenvModules = {
          default = ./modules/devenv;
          # Individual modules for devenv
          secrets = ./modules/devenv/secrets.nix;
          aws = ./modules/devenv/aws.nix;
          network = ./modules/devenv/network.nix;
          theme = ./modules/devenv/theme.nix;
        };

        # ════════════════════════════════════════════════════════════════════
        # Templates
        # ════════════════════════════════════════════════════════════════════
        templates = {
          default = {
            path = ./templates/default;
            description = "Basic stackpanel project with flake.nix";
          };
          devenv = {
            path = ./templates/devenv;
            description = "stackpanel project with devenv.yaml (no flake)";
          };
        };

        # ════════════════════════════════════════════════════════════════════
        # Library functions (pure Nix, works with any module system)
        #
        # Usage:
        #   let stackpanelLib = inputs.stackpanel.lib { inherit pkgs lib; };
        #   in stackpanelLib.aws.mkAwsCredScripts { ... }
        # ════════════════════════════════════════════════════════════════════
        lib = { pkgs ? null, lib ? nixpkgs.lib }: import ./lib { inherit pkgs lib; };
      };
    };
}
