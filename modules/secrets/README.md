# secrets/

Secrets management via agenix - team pubkeys, secret definitions, and auto-rekey workflow.

## Files

| File | Purpose |
|------|---------|
| `default.nix` | Module entrypoint |
| `users.nix` | User/team options, secrets.nix generation, rekey workflow |
| `exec.nix` | secrets-exec, secrets-edit, secrets-list commands |

## Options

```nix
stackpanel.secrets = {
  enable = true;
  
  users = {
    alice = { pubkey = "ssh-ed25519 ..."; admin = true; };
    bob = { pubkey = "ssh-ed25519 ..."; };
  };
  
  secrets = {
    "api-key.age".owners = [ "alice" "bob" ];
    "db-password.age".owners = [ "alice" ];  # admin-only
  };
  
  rekey = {
    enable = true;  # GitHub Action to auto-rekey
    sshKeySecret = "AGENIX_SSH_KEY";
  };
};
```

## Commands

### `nix run .#secrets-list`
List all secrets and their corresponding environment variable names.

```bash
$ nix run .#secrets-list
Secrets in secrets:
  api-key.age -> $API_KEY
  db-password.age -> $DB_PASSWORD
```

### `nix run .#secrets-exec -- <command>`
Run a command with all decrypted secrets loaded as environment variables. Similar to `sops exec-env`.

```bash
# Run a command with secrets
$ nix run .#secrets-exec -- ./deploy.sh

# Quick test
$ nix run .#secrets-exec -- printenv API_KEY
sk-abc123...

# Start a development server with secrets
$ nix run .#secrets-exec -- npm run dev
```

Secret files are converted to env var names:
- `api-key.age` → `$API_KEY`  
- `db-password.age` → `$DB_PASSWORD`
- `stripe.api.key.age` → `$STRIPE_API_KEY`

### `nix run .#secrets-edit <name>`
Edit or create a secret. Wrapper around `agenix -e`.

```bash
$ nix run .#secrets-edit api-key
# Opens $EDITOR with decrypted content
```

## Generated Files

- `secrets/secrets.nix` - agenix format, lists pubkeys + secret owners
- `.github/workflows/rekey.yml` - auto-rekey when secrets.nix changes

## Workflow

1. Agent syncs team → writes `.stackpanel/team.nix`
2. User imports in flake: `users = (import ./.stackpanel/team.nix).users`
3. `nix run .#generate` creates `secrets/secrets.nix`
4. User encrypts: `nix run .#secrets-edit api-key`
5. On push, GitHub Action rekeys if secrets.nix changed
6. In dev: `nix run .#secrets-exec -- ./start-dev.sh`

## TODO

- [ ] Support system keys (CI, servers) separate from user keys
- [ ] Add secret rotation reminders
- [ ] Integration with devenv for automatic secret loading
