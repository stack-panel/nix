# stackpanel/nix

Nix flake providing composable modules for full-stack project management.

## Architecture

```
Agent (Go)                    Nix Modules                    Generated Files
    │                              │                              │
    │  writes                      │  transforms                  │
    ▼                              ▼                              ▼
.stackpanel/               stackpanel.files.*           .github/workflows/
├── team.nix          ───►  (accumulator)         ───►  secrets/secrets.nix
├── config.nix                                          Dockerfile
└── ...                                                 etc.
```

## Installation

There are multiple ways to use stackpanel depending on your Nix setup:

### Option 1: Standalone Modules (Primary)

The core modules are **standalone NixOS-style modules** with no dependency on flake-parts. They work with `lib.evalModules`, NixOS configurations, or any custom module system.

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    stackpanel.url = "github:stack-panel/nix";
  };

  outputs = { nixpkgs, stackpanel, ... }:
  let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
    lib = nixpkgs.lib;
    
    # Evaluate stackpanel modules standalone
    stackpanelConfig = lib.evalModules {
      modules = [
        stackpanel.nixosModules.default
        {
          config._module.args.pkgs = pkgs;
          config.stackpanel = {
            enable = true;
            secrets.enable = true;
            aws.certAuth = {
              enable = true;
              accountId = "123456789";
              roleName = "my-role";
              trustAnchorArn = "arn:aws:rolesanywhere:...";
              profileArn = "arn:aws:rolesanywhere:...";
            };
          };
        }
      ];
    };
  in {
    packages.${system} = stackpanelConfig.config.stackpanel.packages;
    
    devShells.${system}.default = pkgs.mkShell {
      packages = builtins.attrValues stackpanelConfig.config.stackpanel.packages;
    };
  };
}
```

### Option 2: flake-parts Integration

For projects using `flake.nix` with flake-parts:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    stackpanel.url = "github:stack-panel/nix";
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ inputs.stackpanel.flakeModules.default ];

      systems = [ "x86_64-linux" "aarch64-darwin" ];

      perSystem = { ... }:
      let
        teamData = import ./.stackpanel/team.nix;
      in {
        stackpanel = {
          secrets = {
            enable = true;
            users = teamData.users;
          };
          ci.github.enable = true;
        };
      };
    };
}
```

Then: `nix run .#generate`

### Option 3: devenv.yaml (No Flake)

For projects using devenv without a `flake.nix`:

```yaml
# devenv.yaml
inputs:
  stackpanel:
    url: github:stack-panel/nix

imports:
  - stackpanel/devenvModules/default
```

```nix
# devenv.nix
{ config, ... }:
{
  stackpanel = {
    enable = true;
    secrets.enable = true;
    aws.certAuth.enable = true;
  };
}
```

### Option 4: Non-Flake (nix-shell / nix-build)

For projects without flakes enabled, you can use the legacy compatibility layer:

```bash
# Enter dev shell
nix-shell -I stackpanel=github:stack-panel/nix \
  -p '(import <stackpanel>).packages.${builtins.currentSystem}.default'

# Or clone and use directly
git clone https://github.com/stack-panel/nix stackpanel-nix
nix-shell stackpanel-nix/shell.nix
```

## Templates

Bootstrap a new project:

```bash
# With flake-parts
nix flake init -t github:stack-panel/nix

# With devenv.yaml
nix flake init -t github:stack-panel/nix#devenv
```

## Module Status

| Module | Status | Description |
|--------|--------|-------------|
| `core` | ✅ Working | Base options, file generation, datadir |
| `secrets` | ✅ Working | SOPS integration, team management |
| `ci` | ✅ Working | GitHub Actions generation |
| `aws` | ✅ Working | AWS Roles Anywhere cert-based auth |
| `network` | ✅ Working | Step CA certificate management |
| `theme` | ✅ Working | Starship prompt theming |
| `container` | 🚧 Scaffold | Dockerfile generation |

## Architecture

stackpanel uses a **layered architecture** that separates pure logic from module system glue:

```
┌─────────────────────────────────────────────────────────────────┐
│                        lib/ (Pure Nix)                          │
│  aws.nix, network.nix, theme.nix                                │
│  Pure functions that work with any Nix module system            │
└─────────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
┌──────────────────┐ ┌──────────────────┐ ┌──────────────────────┐
│ modules/         │ │ flake-parts.nix  │ │ modules/devenv/      │
│ (Standalone)     │ │ (Wrapper)        │ │ (devenv)             │
│ Primary modules  │ │ perSystem bridge │ │ devenv.yaml users    │
│ No dependencies  │ │ for flake-parts  │ │                      │
└──────────────────┘ └──────────────────┘ └──────────────────────┘
```

This means:
- **Standalone first** - Core modules have no flake-parts dependency
- **Same logic** powers all integration layers
- **No duplication** - Shared lib contains the actual implementation
- **Easy to extend** - Add new module systems by wrapping the lib

### Using the Library Directly

For advanced use cases, you can use the library functions directly:

```nix
{
  inputs.stackpanel.url = "github:stack-panel/nix";
  
  outputs = { nixpkgs, stackpanel, ... }:
  let
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
    lib = nixpkgs.lib;
    
    # Get the library with pkgs
    spLib = stackpanel.lib { inherit pkgs lib; };
    
    # Use library functions directly
    awsScripts = spLib.aws.mkAwsCredScripts {
      stateDir = ".stackpanel/state/aws";
      accountId = "123456789";
      roleName = "my-role";
      trustAnchorArn = "arn:aws:rolesanywhere:...";
      profileArn = "arn:aws:rolesanywhere:...";
    };
  in {
    devShells.x86_64-linux.default = pkgs.mkShell {
      packages = awsScripts.allPackages;
    };
  };
}
```

## Commands

```bash
nix run .#generate        # Write all managed files
nix run .#generate-diff   # Preview what would be written
```

## Secrets Workflow

stackpanel uses **SOPS** with AGE encryption. 

**Editing secrets:**
```bash
sops secrets/dev.yaml        # Edit dev secrets
sops secrets/production.yaml # Edit production secrets
```

**Using secrets in dev:**
```bash
# Run command with secrets as env vars
sops exec-env secrets/dev.yaml './start-server.sh'
```

## Flake Outputs

| Output | Description |
|--------|-------------|
| `nixosModules.*` | **Primary** - Standalone NixOS-style modules (no flake-parts dependency) |
| `flakeModules.default` | **Secondary** - flake-parts integration wrapper |
| `devenvModules.*` | Modules for devenv.yaml users |
| `lib` | Pure library functions for direct use |
| `templates.*` | Project templates |

## TODO

- [x] Template for `nix flake init -t github:stack-panel/nix`
- [x] Devenv integration (devenvModules)
- [x] Non-flake compatibility (default.nix, shell.nix)
- [x] Standalone modules (no flake-parts dependency)
- [ ] Integration tests
- [ ] VSCode module

## Maintenance Notes

**✅ Zero Maintenance Required**

|                 File                 |               Why                   |
|--------------------------------------|-------------------------------------|
| default.nix                          |  Auto-wraps flake.nix via flake-compat. Any new flake outputs are automatically available.  |
| shell.nix                            |  Just returns .shellNix from default.nix. No changes needed. |
| New options within existing modules  |  Just add them to the module - they work automatically. |


**⚠️ Manual Updates Needed**

| When You...                          | Update These                        |
|--------------------------------------|-------------------------------------|
| Add a new top-level module (e.g., modules/database/) | Add to nixosModules in flake.nix |
| Want it to work with devenv.yaml | Also create modules/devenv/<name>.nix and add to devenvModules in flake.nix |
| Add a new template    | Add to templates in flake.nix and create templates/<name>/ directory |

### File Structure

```
nix/
├── flake.nix           # Main flake - exports nixosModules, flakeModules, devenvModules, templates, lib
├── default.nix         # flake-compat wrapper (auto-wraps flake.nix, no maintenance needed)
├── shell.nix           # nix-shell compat (auto-wraps flake.nix, no maintenance needed)
├── lib/                # Pure Nix library (works with any module system)
│   ├── default.nix     # Library index
│   ├── aws.nix         # AWS cert-auth utilities
│   ├── network.nix     # Step CA utilities
│   ├── theme.nix       # Starship theme utilities
│   └── starship.toml   # Default starship config
├── modules/            # Standalone NixOS-style modules (PRIMARY)
│   ├── default.nix     # Module index
│   ├── flake-parts.nix # flake-parts wrapper (SECONDARY)
│   ├── core/           # Core module (file generation)
│   ├── secrets/        # SOPS secrets module
│   ├── ci/             # GitHub Actions module
│   ├── aws/            # AWS cert-auth module
│   ├── network/        # Step CA module
│   ├── theme/          # Starship theme module
│   ├── container/      # Container generation module (WIP)
│   └── devenv/         # Devenv-specific wrappers
│       ├── default.nix
│       ├── secrets.nix
│       ├── aws.nix
│       ├── network.nix
│       └── theme.nix
└── templates/
    ├── default/        # flake-parts template
    └── devenv/         # devenv.yaml template
```
