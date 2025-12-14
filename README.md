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

### Option 1: flake-parts (Recommended)

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
            secrets."api-key.age".owners = [ "alice" ];
          };
          ci.github.enable = true;
        };
      };
    };
}
```

Then: `nix run .#generate`

### Option 2: devenv.yaml (No Flake)

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

### Option 3: Plain Flake (No flake-parts)

For projects using a plain `flake.nix` without flake-parts, import the modules directly:

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
  in {
    devShells.${system}.default = pkgs.mkShell {
      # Use stackpanel lib functions directly
      packages = [ ];
    };
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
| `secrets` | ✅ Working | Agenix integration, team management, rekey workflow |
| `ci` | ✅ Working | GitHub Actions generation |
| `devenv` | 🚧 Scaffold | Devenv wrapper |
| `network` | 🚧 Scaffold | Tailscale, DNS, certificates |
| `container` | 🚧 Scaffold | Dockerfile generation |
| `aws` | 🚧 Scaffold | AWS infrastructure |

## Commands

```bash
nix run .#generate        # Write all managed files
nix run .#generate-diff   # Preview what would be written
nix run .#secrets-exec    # Run command with decrypted secrets (like sops exec-env)
```

## Secrets Workflow

stackpanel uses **agenix** (age-based encryption). Unlike sops which stores secrets inline in YAML, agenix uses separate `.age` files.

**Encrypting a secret:**
```bash
cd secrets
agenix -e api-key.age    # Opens $EDITOR, encrypts on save
```

**Using secrets in dev:**
```bash
# Option 1: agenix CLI (if you have the private key)
agenix -d secrets/api-key.age

# Option 2: stackpanel exec-env (sops-style)
nix run .#secrets-exec -- 'echo $API_KEY'
```

## TODO

- [x] Template for `nix flake init -t github:stack-panel/nix`
- [x] Devenv integration (devenvModules)
- [x] Non-flake compatibility (default.nix, shell.nix)
- [ ] Integration tests
- [ ] VSCode module

## Maintenance Notes

**✅ Zero Maintenance Required**

|                 File                 |               Why                   |
|--------------------------------------|-------------------------------------|
| default.nix                          |  Auto-wraps flake.nix via flake-compat. Any new flake outputs are automatically available.  |
| shell.nix                            |  Just returns .shellNix from default.nix. No changes needed.
New options within existing modules	Just add them to the module - they work automatically. |


**⚠️ Manual Updates Needed**

|                 File                 |               Why                   |
|--------------------------------------|-------------------------------------|
| When You...                          | Update These                        |
| Add a new top-level module (e.g., modules/database/) | Add to flakeModules in flake.nix |
| Want it to work with devenv.yaml | Also create modules/devenv/<name>.nix and add to devenvModules in flake.nix |
| Add a new template    | Add to templates in flake.nix and create templates/<name>/ directory |

**Practical Example**

If you add a new modules/docker/ module:


```nix
# In flake.nix, add:
flakeModules = {
  # ...existing
  docker = ./modules/docker;  # ← Add this
};

# If you also want devenv.yaml support:
devenvModules = {
  # ...existing
  docker = ./modules/devenv/docker.nix;  # ← Add this
};
```

### File Structure

```
nix/
├── flake.nix           # Main flake - exports flakeModules, devenvModules, templates
├── default.nix         # flake-compat wrapper (auto-wraps flake.nix, no maintenance needed)
├── shell.nix           # nix-shell compat (auto-wraps flake.nix, no maintenance needed)
├── modules/
│   ├── default.nix     # flake-parts module index
│   ├── core/           # Core module
│   ├── secrets/        # Secrets module
│   ├── ci/             # CI module
│   ├── network/        # Network module
│   ├── aws/            # AWS module
│   └── devenv/         # Devenv-specific wrappers
│       ├── default.nix
│       ├── secrets.nix
│       ├── aws.nix
│       └── network.nix
└── templates/
    ├── default/        # flake-parts template
    └── devenv/         # devenv.yaml template
```






### When Adding New Modules

1. **Create the module** in `modules/<name>/` with flake-parts options
2. **Export in flakeModules** - Add to `flake.nix`:
   ```nix
   flakeModules = {
     # ...existing
     newmodule = ./modules/newmodule;
   };
   ```
3. **Create devenv wrapper** (optional) - If the module should work with devenv.yaml users:
   - Create `modules/devenv/<name>.nix` that wraps your options for devenv
   - Export in `devenvModules` in `flake.nix`

### What Requires NO Maintenance

- **`default.nix`** - Automatically wraps `flake.nix` via flake-compat
- **`shell.nix`** - Automatically returns the devShell from flake.nix
- **New options within existing modules** - Just add them to the module

### What Requires Manual Updates

| Change | Files to Update |
|--------|-----------------|
| New top-level module | `flake.nix` (flakeModules) |
| New devenv-compatible module | `flake.nix` (devenvModules), `modules/devenv/<name>.nix` |
| New template | `flake.nix` (templates), `templates/<name>/` |