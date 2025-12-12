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

## Usage

```nix
{
  inputs.stackpanel.url = "github:stack-panel/nix";

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ inputs.stackpanel.flakeModules.default ];

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

- [ ] Template for `nix flake init -t github:stack-panel/nix`
- [ ] Integration tests
- [ ] VSCode module
- [ ] Devenv integration