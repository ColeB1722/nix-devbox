# Quickstart: Testing Infrastructure

**Feature**: 002-testing-infrastructure

## Prerequisites

- Nix with flakes enabled
- Git repository initialized

## Installing Nix

If you don't have Nix installed, use the Determinate Systems installer (recommended):

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

This installer:
- Enables flakes by default
- Works on Linux and macOS
- Provides an uninstall option
- Same installer used in CI

After installation, restart your shell or run:
```bash
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
```

## Quick Setup

### 1. Enter the Development Shell

```bash
nix develop
```

This automatically:
- Installs pre-commit hooks (code quality + security)
- Provides all linting tools in your PATH
- Prints confirmation when hooks are installed

### 2. Make Changes and Commit

Hooks run automatically on `git commit`:

**Code Quality:**
- **nixfmt-rfc-style**: Formats all `.nix` files
- **statix**: Detects antipatterns and inefficient code
- **deadnix**: Finds unused variables and arguments

**Security:**
- **gitleaks**: Scans for secrets, API keys, and credentials
- **detect-private-key**: Blocks commits containing private keys
- **check-ssh-keys**: Verifies SSH keys are safe for public repo

If any hook fails, the commit is blocked until issues are fixed.

### 3. Manual Hook Execution

Run all hooks on all files:
```bash
nix develop -c pre-commit run --all-files
```

Run a specific hook:
```bash
# Code quality
nix develop -c pre-commit run nixfmt-rfc-style --all-files
nix develop -c pre-commit run statix --all-files
nix develop -c pre-commit run deadnix --all-files

# Security
nix develop -c pre-commit run gitleaks --all-files
nix develop -c pre-commit run detect-private-key --all-files
nix develop -c pre-commit run check-ssh-keys --all-files
```

### 4. Full Validation

Run complete flake checks (includes pre-commit + NixOS build):
```bash
nix flake check
```

**Note**: On macOS, Linux-specific checks are skipped but hook configuration is validated.

## CI Workflow

GitHub Actions runs the full pipeline on protected branches only:

| Trigger | Format Check | Flake Check | Build |
|---------|--------------|-------------|-------|
| Push to feature branch | No | No | No |
| PR targeting `main` or `release/*` | Yes | Yes | Yes |
| Push to `release/*` | Yes | Yes | Yes |
| Push to `main` | Yes | Yes | Yes |

Feature branches rely on pre-commit hooks for local validation. CI runs when you open a PR or push directly to protected branches.

## Fixing Issues

### Format Errors (nixfmt)

Auto-fix by running:
```bash
nix develop -c nixfmt .
```

Or let the hook fix files (it modifies in-place), then re-add:
```bash
git add -u && git commit
```

### Linting Errors (statix)

View suggestions:
```bash
nix develop -c statix check .
```

Auto-fix (where possible):
```bash
nix develop -c statix fix .
```

### Dead Code (deadnix)

View unused bindings:
```bash
nix develop -c deadnix .
```

Auto-fix (removes unused code):
```bash
nix develop -c deadnix -e .
```

### Secret Detection (gitleaks)

Gitleaks blocks commits containing secrets. If you get a false positive:

1. **Verify it's not a real secret** — check the flagged content
2. **Add to `.gitleaksignore`** — if it's a known-safe pattern
3. **Use `--no-verify`** — emergency only, CI will still catch it

### SSH Key Verification (check-ssh-keys)

Only these SSH key patterns are allowed in the repo:
- `ci-test-key@nix-devbox` — CI test key (no private key exists)
- Keys containing "Placeholder" — obvious placeholders
- Keys in comments (e.g., `# Example:`)

If you need to add your real SSH key for deployment, do NOT commit it. Use a secret management solution like `agenix` or `sops-nix` instead.

## Skipping Hooks (Emergency Only)

```bash
git commit --no-verify -m "emergency fix"
```

**Warning**: CI will still run checks. Use sparingly.

## Troubleshooting

### Hooks not running

Re-enter the dev shell:
```bash
exit
nix develop
```

### Hook installation failed

Clear and reinstall:
```bash
rm -rf .git/hooks/pre-commit
nix develop
```

### CI failing but local passes

Ensure you're testing on the same system:
```bash
# Local test mimicking CI (Linux checks only)
nix flake check --system x86_64-linux
```
