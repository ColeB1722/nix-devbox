# Contract: Pre-commit Hook Interfaces

**Feature**: 002-testing-infrastructure
**Version**: 1.0

## Overview

This contract defines the interface between the Nix flake and git-hooks.nix for pre-commit hook execution.

## Flake Output Interface

### checks.${system}.pre-commit-check

**Type**: Derivation (git-hooks.nix run output)

**Required attributes**:
- `shellHook` (string): Shell script for installing hooks
- `enabledPackages` (list): Packages needed for hook execution

**Expected behavior**:
- Returns success (exit 0) when all hooks pass
- Returns failure (exit non-zero) when any hook fails
- Produces no output artifacts beyond hook results

### devShells.${system}.default

**Type**: mkShell derivation

**Required attributes**:
- Inherits `shellHook` from pre-commit-check
- Includes `enabledPackages` in `buildInputs`

**Expected behavior**:
- Entering shell installs/updates git hooks automatically
- Provides all hook tools (nixfmt, statix, deadnix) in PATH

## Hook Configuration Interface

### nixfmt-rfc-style

**Input**: All `*.nix` files in repository
**Output**: Modified files (in-place formatting)
**Exit codes**:
- 0: Success (files formatted or already formatted)
- Non-zero: Error during formatting, or in `--check` mode, files need formatting

### statix

**Input**: All `*.nix` files in repository
**Output**: Diagnostics to stderr
**Exit codes**:
- 0: No issues found
- Non-zero: Issues detected

### deadnix

**Input**: All `*.nix` files in repository
**Output**: Diagnostics to stderr
**Exit codes**:
- 0: No unused code found
- Non-zero: Unused code detected

## CI Interface

### GitHub Actions Workflow

**Trigger**: Push to any branch, pull request to any branch

**Required steps**:
1. Checkout repository
2. Install Nix with flakes enabled
3. Run `nix flake check`
4. Build NixOS configuration

**Expected outputs**:
- Success: All checks pass, build succeeds
- Failure: Any check fails or build fails

### Build Command

```bash
nix build .#nixosConfigurations.devbox.config.system.build.toplevel
```

**Note**: Only runs on x86_64-linux runners (NixOS config is Linux-only)

## Error Handling

### Hook Failures

When a hook fails:
1. Commit is blocked
2. Error output displayed to user
3. User must fix issues and retry commit

### CI Failures

When CI fails:
1. PR is blocked from merging (if branch protection enabled)
2. Failure details available in Actions log
3. Developer must push fixes

## Versioning

This contract follows semantic versioning:
- **Major**: Breaking changes to interface
- **Minor**: New optional features
- **Patch**: Bug fixes, documentation

Current version: 1.0.0
