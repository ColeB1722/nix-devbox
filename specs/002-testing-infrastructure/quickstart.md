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
- Installs pre-commit hooks (nixfmt, statix, deadnix)
- Provides all linting tools in your PATH
- Prints confirmation when hooks are installed

### 2. Make Changes and Commit

Hooks run automatically on `git commit`:
- **nixfmt-rfc-style**: Formats all `.nix` files
- **statix**: Detects antipatterns and inefficient code
- **deadnix**: Finds unused variables and arguments

If any hook fails, the commit is blocked until issues are fixed.

### 3. Manual Hook Execution

Run all hooks on all files:
```bash
nix develop -c pre-commit run --all-files
```

Run a specific hook:
```bash
nix develop -c pre-commit run nixfmt-rfc-style --all-files
nix develop -c pre-commit run statix --all-files
nix develop -c pre-commit run deadnix --all-files
```

### 4. Full Validation

Run complete flake checks (includes pre-commit + NixOS build):
```bash
nix flake check
```

**Note**: On macOS, Linux-specific checks are skipped but hook configuration is validated.

## CI Workflow

GitHub Actions runs different checks based on branch:

| Branch | Format Check | Flake Check | Build |
|--------|--------------|-------------|-------|
| Feature branches | Yes | No | No |
| `release/*` | Yes | Yes | Yes |
| `main` | Yes | Yes | Yes |

This keeps feature branch CI fast while ensuring release branches are fully validated.

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
