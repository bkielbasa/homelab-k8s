# Security Policy

- Never commit real secrets. Use Kubernetes Secrets, Vault, or environment variables.
- This repo ignores common secret files via `.gitignore`.
- If you find a vulnerability or exposed secret, please open a private issue or contact the maintainer directly rather than opening a public PR.

## Reporting
Email: security@klimczak.xyz

## Secret Management
- Helm charts are configured to read credentials from existing Secrets.
- Create secrets out-of-band (kubectl, CI, or Vault) and reference them via `existingSecret` values.
