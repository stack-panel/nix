{
  description = "stackpanel";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    devenv.url = "github:cachix/devenv";
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
            
            # Environment-specific access control
            environments = {
              dev = { users = [ "alice" "bob" "charlie" ]; };
              staging = { users = [ "alice" "bob" ]; };
              production = { 
                users = [ "alice" ];
                # extraKeys = [ "age1..." ];  # CI system key
              };
            };
            
            # Define secrets schema - generates typed modules
            schema = {
              # Sensitive (server-only) secrets
              DATABASE_URL = { 
                required = true; 
                sensitive = true; 
                description = "PostgreSQL connection string"; 
              };
              STRIPE_SECRET_KEY = { 
                required = true; 
                sensitive = true; 
                description = "Stripe API secret key"; 
              };
              OPENAI_API_KEY = { 
                required = false;  # Optional - nullable in generated types
                sensitive = true; 
                description = "OpenAI API key for AI features"; 
              };
              
              # Public (client-safe) secrets - will be PUBLIC_* in env
              STRIPE_PUBLISHABLE_KEY = { 
                required = true; 
                sensitive = false; 
                description = "Stripe publishable key (safe for client)"; 
              };
              ANALYTICS_ID = { 
                required = false; 
                sensitive = false; 
                description = "Google Analytics ID"; 
              };
            };
            
            # Code generation options
            codegen = {
              typescript = {
                enable = true;
                path = "packages/env/src/env.ts";
              };
              python.enable = false;
              go.enable = false;
            };
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
