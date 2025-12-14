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
        # Import stackpanel modules for this flake's own use
        ./modules
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
        # For flake-parts users (flake.nix):
        #   imports = [ inputs.stackpanel.flakeModules.default ];
        # ════════════════════════════════════════════════════════════════════
        flakeModules = {
          default = ./modules;
          core = ./modules/core;
          secrets = ./modules/secrets;
          ci = ./modules/ci;
          network = ./modules/network;
          aws = ./modules/aws;
        };

        # ════════════════════════════════════════════════════════════════════
        # For devenv.yaml users (no flake.nix):
        #   inputs:
        #     stackpanel:
        #       url: github:darkmatter/stackpanel/nix
        #   imports:
        #     - stackpanel/devenvModules/default
        # ════════════════════════════════════════════════════════════════════
        devenvModules = {
          default = ./modules/devenv;
          # Individual modules for devenv
          secrets = ./modules/devenv/secrets.nix;
          aws = ./modules/devenv/aws.nix;
          network = ./modules/devenv/network.nix;
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

        # Library functions
        lib = import ./lib { inherit (nixpkgs) lib; };
      };
    };
}
