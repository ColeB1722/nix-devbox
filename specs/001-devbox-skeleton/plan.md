# Implementation Plan: Devbox Skeleton

**Branch**: `001-devbox-skeleton` | **Date**: 2026-01-17 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-devbox-skeleton/spec.md`

## Summary

Create a minimal, secure, modular NixOS configuration skeleton that serves as the foundation for a self-hosted remote development machine. The skeleton provides SSH access via Tailscale, enforces security-by-default (key-only auth, firewall deny-all), and establishes a composable module structure for future extensibility.

## Technical Context

**Language/Version**: Nix (flakes format, NixOS 24.05+)
**Primary Dependencies**: NixOS modules, Home Manager, Tailscale
**Storage**: N/A (configuration files only, no persistent data storage)
**Testing**: `nixos-rebuild build` for syntax/evaluation, VM testing for integration
**Target Platform**: NixOS on x86_64-linux or aarch64-linux (headless server)
**Project Type**: Single project (Nix flake with modules)
**Performance Goals**: Boot to SSH-ready state within 60 seconds post-kernel
**Constraints**: No GUI, no public internet exposure, reproducible from repo alone
**Scale/Scope**: Single-user personal devbox, 1 machine initially (portable to N machines)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Evidence |
|-----------|--------|----------|
| I. Declarative Configuration | ✅ PASS | All config in Nix flake; FR-009 requires reproducibility |
| II. Headless-First Design | ✅ PASS | No GUI; SSH/Tailscale access only per FR-002, FR-003 |
| III. Security by Default | ✅ PASS | Key-only SSH (FR-003/004), deny root (FR-005), firewall deny-all (FR-006) |
| IV. Modular and Reusable | ✅ PASS | FR-007 mandates composable modules; SC-004 requires 3+ independent modules |
| V. Documentation as Code | ✅ PASS | Quickstart.md deliverable; modules will include comments |

**Gate Result**: PASS - All principles satisfied by design.

## Project Structure

### Documentation (this feature)

```text
specs/001-devbox-skeleton/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output (module structure)
├── quickstart.md        # Phase 1 output (deployment guide)
└── contracts/           # Phase 1 output (N/A for infra - module interfaces)
```

### Source Code (repository root)

```text
flake.nix                # Flake entry point with inputs/outputs
flake.lock               # Pinned dependencies

hosts/
└── devbox/
    ├── default.nix         # Machine-specific config (imports modules)
    └── hardware-configuration.nix  # Generated hardware config (gitignored template)

modules/
├── core/
│   └── default.nix      # Base system settings (locale, timezone, nix settings)
├── networking/
│   ├── default.nix      # Firewall, network basics
│   └── tailscale.nix    # Tailscale service configuration
├── security/
│   └── ssh.nix          # SSH hardening (key-only, no root)
└── user/
    └── default.nix      # User account, Home Manager integration

home/
└── default.nix          # Home Manager config (shell, git, editor basics)
```

**Structure Decision**: Nix flake with modular structure. Hosts directory allows future multi-machine support. Modules directory contains reusable components per constitution principle IV.

## Complexity Tracking

No violations to justify. Design aligns with all constitutional principles.
