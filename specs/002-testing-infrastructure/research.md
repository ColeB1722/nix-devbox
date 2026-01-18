# Research: Testing Infrastructure

**Feature**: 002-testing-infrastructure
**Date**: 2026-01-17

## Pre-commit Hook Integration

### Decision: Use git-hooks.nix from Cachix

**Rationale**: git-hooks.nix (formerly pre-commit-hooks.nix) is the standard integration for pre-commit hooks in Nix projects. It provides:
- Seamless flake integration with `checks` and `devShells` outputs
- Automatic hook installation when entering the dev shell
- Sandboxed execution via `nix flake check`
- Built-in support for all required tools (nixfmt, statix, deadnix)

**Alternatives considered**:
- Manual pre-commit configuration: Rejected - requires separate tool installation, not reproducible
- lefthook: Rejected - not Nix-native, less integration with flake ecosystem
- husky: Rejected - Node.js focused, inappropriate for Nix project

### Configuration Pattern

```nix
inputs = {
  git-hooks.url = "github:cachix/git-hooks.nix";
};

outputs = { self, nixpkgs, git-hooks, ... }: {
  checks.x86_64-linux.pre-commit-check = git-hooks.lib.x86_64-linux.run {
    src = ./.;
    hooks = {
      nixfmt-rfc-style.enable = true;
      statix.enable = true;
      deadnix.enable = true;
    };
  };
  
  devShells.x86_64-linux.default = pkgs.mkShell {
    inherit (self.checks.x86_64-linux.pre-commit-check) shellHook;
    buildInputs = self.checks.x86_64-linux.pre-commit-check.enabledPackages;
  };
};
```

## Nix Formatting Tool Selection

### Decision: Use nixfmt (RFC-style)

**Rationale**: nixfmt is being standardized as the official formatter for nixpkgs via RFC 166. Using `nixfmt-rfc-style` ensures compatibility with the emerging standard.

**Alternatives considered**:
- alejandra: Rejected - opinionated formatter, not the official standard
- nixpkgs-fmt: Rejected - archived, development stopped in favor of nixfmt

**Key setting**: Use `nixfmt-rfc-style` hook (not legacy `nixfmt`)

## Linting Tool Selection

### Decision: Use statix for antipattern detection

**Rationale**: statix is the most comprehensive Nix linter, detecting:
- Useless parentheses
- Empty let bindings
- Deprecated builtins
- Inefficient patterns (e.g., `if x then true else false`)

**Configuration**: Default settings are sufficient; no custom rules needed.

## Dead Code Detection

### Decision: Use deadnix for unused variable detection

**Rationale**: deadnix specifically targets:
- Unused function arguments
- Unused let bindings
- Unused pattern bindings

This complements statix which focuses on antipatterns rather than dead code.

## Multi-system Support

### Decision: Support both x86_64-linux and aarch64-darwin

**Rationale**: 
- Development occurs on macOS (aarch64-darwin)
- NixOS deployment targets Linux (x86_64-linux)
- CI runs on Linux (ubuntu-latest = x86_64-linux)

**Pattern**: Use `forEachSystem` helper with systems list:
```nix
systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
```

## CI Platform Selection

### Decision: GitHub Actions with DeterminateSystems/nix-installer-action

**Rationale**:
- GitHub Actions is free for public repositories
- DeterminateSystems/nix-installer-action is the modern, recommended installer
- Includes automatic flake support and caching capabilities
- Simpler than cachix/install-nix-action for basic use cases

**Alternatives considered**:
- cachix/install-nix-action: Valid but older approach, more configuration needed
- Self-hosted runners: Rejected - maintenance overhead for personal project

### CI Workflow Pattern

```yaml
name: CI
on: [push, pull_request]
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: DeterminateSystems/nix-installer-action@main
      - uses: DeterminateSystems/magic-nix-cache-action@main
      - run: nix flake check
      - run: nix build .#nixosConfigurations.devbox.config.system.build.toplevel
```

## Local Validation Commands

### Decision: Provide multiple validation entry points

**Commands**:
1. `nix flake check` - Full sandboxed validation (hooks + NixOS build on Linux)
2. `nix develop -c pre-commit run --all-files` - Manual hook execution
3. `nix fmt` - Format all files (if formatter output configured)

**Note**: `nix flake check` on macOS will skip Linux-only checks but still validate hook configuration.

## DevShell Auto-Installation

### Decision: Use shellHook for automatic hook installation

**Rationale**: git-hooks.nix provides a `shellHook` that:
- Installs git hooks on shell entry
- Only runs if hooks have changed (idempotent)
- Prints confirmation message

**Pattern**:
```nix
devShells.default = pkgs.mkShell {
  inherit (self.checks.${system}.pre-commit-check) shellHook;
  buildInputs = self.checks.${system}.pre-commit-check.enabledPackages;
};
```

## Summary

| Area | Decision | Key Rationale |
|------|----------|---------------|
| Hook framework | git-hooks.nix | Nix-native, flake integrated |
| Formatter | nixfmt-rfc-style | Emerging nixpkgs standard |
| Linter | statix | Comprehensive antipattern detection |
| Dead code | deadnix | Complements statix for unused code |
| CI platform | GitHub Actions | Free, well-supported |
| Nix installer | DeterminateSystems | Modern, automatic flake support |
| Multi-system | forEachSystem | macOS dev + Linux CI/deploy |
