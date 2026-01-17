# Data Model: Testing Infrastructure

**Feature**: 002-testing-infrastructure
**Date**: 2026-01-17

> Note: For infrastructure-as-code projects, "data model" describes the configuration structure and flake outputs rather than traditional database entities.

## Flake Architecture Extension

### Extended Flake Dependency Graph

```text
flake.nix
    │
    ├── inputs
    │   ├── nixpkgs (existing)
    │   ├── home-manager (existing)
    │   ├── git-hooks.url = "github:cachix/git-hooks.nix"  [NEW]
    │   └── systems.url = "github:nix-systems/default"     [NEW]
    │
    └── outputs
        ├── nixosConfigurations.devbox (existing)
        ├── checks.${system}.pre-commit-check            [NEW]
        └── devShells.${system}.default                  [NEW]
```

## Configuration Entities

### 1. Git Hooks Input

**Location**: `flake.nix` inputs
**Purpose**: Provide pre-commit hook framework

| Attribute | Type | Value |
|-----------|------|-------|
| url | string | "github:cachix/git-hooks.nix" |
| inputs.nixpkgs.follows | string | "nixpkgs" |

### 2. Systems Input

**Location**: `flake.nix` inputs
**Purpose**: Define supported system architectures

| Attribute | Type | Value |
|-----------|------|-------|
| url | string | "github:nix-systems/default" |

**Provides systems**: x86_64-linux, aarch64-linux, x86_64-darwin, aarch64-darwin

### 3. Pre-commit Check Configuration

**Location**: `flake.nix` outputs → `checks.${system}.pre-commit-check`
**Purpose**: Define which hooks run and their configuration

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| src | path | `./.` | Repository root |
| hooks.nixfmt-rfc-style.enable | bool | true | Enable nixfmt formatter |
| hooks.statix.enable | bool | true | Enable statix linter |
| hooks.deadnix.enable | bool | true | Enable dead code detection |

**Outputs provided**:
- `shellHook`: Script to install git hooks
- `enabledPackages`: List of hook tool packages
- `config`: Pre-commit configuration object

### 4. Development Shell

**Location**: `flake.nix` outputs → `devShells.${system}.default`
**Purpose**: Provide development environment with auto-installed hooks

| Attribute | Type | Source | Description |
|-----------|------|--------|-------------|
| shellHook | string | pre-commit-check | Script that installs git hooks |
| buildInputs | list | enabledPackages | Hook tool packages |

**State transitions**:
- Shell entry → shellHook runs → Hooks installed (if needed)
- `git commit` → Pre-commit hooks execute → Pass/Fail

### 5. CI Workflow Configuration

**Location**: `.github/workflows/ci.yml`
**Purpose**: Automated validation on push/PR

| Attribute | Type | Value | Description |
|-----------|------|-------|-------------|
| on | object | push, pull_request | Trigger events |
| runs-on | string | ubuntu-latest | Runner environment |
| steps | list | [checkout, nix, cache, check, build] | Job steps |

**Job Steps**:
1. `actions/checkout@v4` - Clone repository
2. `DeterminateSystems/nix-installer-action@main` - Install Nix
3. `DeterminateSystems/magic-nix-cache-action@main` - Enable caching
4. `nix flake check` - Run all checks
5. `nix build .#nixosConfigurations.devbox.config.system.build.toplevel` - Build NixOS config

## Hook Execution Flow

```text
Developer commits code
         │
         ▼
┌─────────────────────────┐
│   Pre-commit Hooks      │
│                         │
│  ┌───────────────────┐  │
│  │ 1. nixfmt-rfc     │──┼──► Format check/fix
│  └───────────────────┘  │
│           │             │
│           ▼             │
│  ┌───────────────────┐  │
│  │ 2. statix         │──┼──► Lint for antipatterns
│  └───────────────────┘  │
│           │             │
│           ▼             │
│  ┌───────────────────┐  │
│  │ 3. deadnix        │──┼──► Detect unused code
│  └───────────────────┘  │
│                         │
└─────────────────────────┘
         │
         ▼
    All pass? ──No──► Commit blocked, show errors
         │
        Yes
         │
         ▼
    Commit succeeds
```

## CI Execution Flow

```text
Push/PR to repository
         │
         ▼
┌─────────────────────────────────────┐
│   GitHub Actions (ubuntu-latest)    │
│                                     │
│  ┌─────────────────────────────┐    │
│  │ 1. Install Nix              │    │
│  └─────────────────────────────┘    │
│           │                         │
│           ▼                         │
│  ┌─────────────────────────────┐    │
│  │ 2. nix flake check          │────┼──► Validate hooks + structure
│  └─────────────────────────────┘    │
│           │                         │
│           ▼                         │
│  ┌─────────────────────────────┐    │
│  │ 3. Build NixOS config       │────┼──► Verify full system builds
│  └─────────────────────────────┘    │
│                                     │
└─────────────────────────────────────┘
         │
         ▼
    All pass? ──No──► PR/push marked failed
         │
        Yes
         │
         ▼
    PR/push marked passed
```

## Cross-Output Dependencies

```text
┌──────────────────────────────────────────────────────────────┐
│                        flake.nix                              │
└──────────────────────────────────────────────────────────────┘
          │
          ├── inputs.git-hooks ─────────────────────────────────┐
          │                                                      │
          └── outputs                                            │
                │                                                │
                ├── checks.${system}.pre-commit-check ◄──────────┘
                │         │                          uses git-hooks.lib
                │         │
                │         ├── shellHook ──────────────┐
                │         │                           │
                │         └── enabledPackages ────────┼───┐
                │                                     │   │
                │                                     │   │
                └── devShells.${system}.default ◄─────┴───┘
                          uses shellHook + enabledPackages
```

## Validation Rules

| Check | Enforcement | Failure Behavior |
|-------|-------------|------------------|
| Nix formatting | Pre-commit hook | Block commit, show diff |
| Linting (statix) | Pre-commit hook | Block commit, show violations |
| Dead code (deadnix) | Pre-commit hook | Block commit, list unused |
| Flake structure | `nix flake check` | Exit non-zero, show error |
| NixOS build | CI only | Mark PR/push as failed |
