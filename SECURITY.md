# Security Policy

## Reporting a Vulnerability

We take the security of stackpanel seriously. If you believe you have found a security vulnerability, please report it to us as described below.

## Supported Versions

We release patches for security vulnerabilities for the following versions:

| Version | Supported          |
| ------- | ------------------ |
| latest  | :white_check_mark: |

## Reporting a Vulnerability

**Please do not report security vulnerabilities through public GitHub issues.**

Instead, please report them via:
- GitHub Security Advisories: Use the "Security" tab in this repository
- Email: [Create an issue with tag [SECURITY] in the title]

Please include the following information:
- Type of issue (e.g. buffer overflow, SQL injection, cross-site scripting, etc.)
- Full paths of source file(s) related to the manifestation of the issue
- The location of the affected source code (tag/branch/commit or direct URL)
- Any special configuration required to reproduce the issue
- Step-by-step instructions to reproduce the issue
- Proof-of-concept or exploit code (if possible)
- Impact of the issue, including how an attacker might exploit it

## Response Timeline

- We will acknowledge receipt of your vulnerability report within 3 business days
- We will send you a more detailed response within 7 days indicating the next steps
- We will keep you informed of the progress towards a fix and announcement

## Security Best Practices

When using stackpanel:

1. **Never commit unencrypted secrets**
   - Always use SOPS/age encryption for sensitive data
   - Use `.gitignore` patterns to exclude unencrypted files

2. **Protect private keys**
   - Store age private keys securely (e.g., `~/.config/sops/age/keys.txt`)
   - Never commit private keys to version control
   - Rotate keys if compromised

3. **Limit secret access**
   - Use environment-specific key configurations
   - Grant minimal necessary access to team members
   - Regularly audit who has access to secrets

4. **Keep dependencies updated**
   - Regularly update Nix flake inputs
   - Monitor for security advisories

5. **Use secret scanning**
   - Enable GitHub secret scanning
   - Use pre-commit hooks to prevent accidental commits
   - Consider tools like gitleaks for additional protection

## Encryption System

stackpanel uses [SOPS](https://github.com/getsops/sops) with [age](https://github.com/FiloSottile/age) encryption:

- **Public keys** can be safely committed (required for encryption)
- **Private keys** must be kept secret and never committed
- Encrypted files (`.age` format) are safe to commit
- Local override files (`*.local.yaml`) are gitignored by default

## Known Limitations

- Secret files must be manually encrypted using SOPS
- Access control is enforced at encryption time, not runtime
- Team member removal requires re-keying secrets
