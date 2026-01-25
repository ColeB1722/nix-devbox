# Implementation Plan: Extended Development Tools

**Branch**: `008-extended-devtools` | **Date**: 2026-01-25 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/008-extended-devtools/spec.md`

## Summary

Install additional development tools across platforms: CLI tools (goose, cargo, yazi) via Home Manager, container runtime (Podman) and services (ttyd, Syncthing) via NixOS modules, with platform-specific desktop tools (Aerospace for macOS, Hyprland for headed NixOS) as opt-in modules. This feature provides the Podman foundation required by `009-devcontainer-orchestrator`.

## Technical Context

**Language/Version**: Nix (flakes), NixOS 25.05
**Primary Dependencies**: nixpkgs, home-manager, nixos-wsl, (future: nix-darwin)
**Storage**: N/A (configuration-only, no runtime storage)
**Testing**: `nix flake check`, `nixos-rebuild build`, manual validation per acceptance criteria
**Target Platform**: NixOS (bare-metal, WSL), nix-darwin (planned)
**Project Type**: Nix configuration repository (modules and host definitions)
**Performance Goals**: N/A (configuration-time only; tool performance is tool-specific)
**Constraints**: No secrets in repository, services (ttyd, Syncthing) must bind to Tailscale interface only
**Scale/Scope**: 2 users, 2 host configurations (devbox, devbox-wsl), future Darwin support

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| **I. Declarative Configuration** | ✅ PASS | All tools declared in Nix modules; no imperative changes |
| **II. Headless-First Design** | ⚠️ VIOLATION | Aerospace (macOS GUI) and Hyprland (Linux desktop) violate headless-first |
| **III. Security by Default** | ✅ PASS | ttyd/Syncthing bind to Tailscale only; Podman is rootless; no secrets in repo |
| **IV. Modular and Reusable** | ✅ PASS | Each concern in separate module; platform-specific modules isolated |
| **V. Documentation as Code** | ✅ PASS | All modules include inline comments explaining decisions |

### Gate Status: CONDITIONAL PASS

Proceed with Complexity Tracking justification for Principle II violation.

## Project Structure

### Documentation (this feature)

```text
specs/008-extended-devtools/
├── plan.md              # This file
├── research.md          # Phase 0 output - tool availability and patterns
├── data-model.md        # Phase 1 output - module interface definitions
├── quickstart.md        # Phase 1 output - usage instructions
└── contracts/           # Phase 1 output - N/A (no APIs)
```

### Source Code (repository root)

```text
# Home Manager modules (user-space tools)
home/modules/
├── cli.nix              # Existing - add yazi here
├── dev.nix              # Existing - add goose, cargo here
└── ...

# NixOS modules (system services)
nixos/
├── podman.nix           # NEW - Podman rootless container runtime
├── ttyd.nix             # NEW - Web terminal sharing service
├── syncthing.nix        # NEW - File synchronization service
├── hyprland.nix         # NEW - Wayland compositor (opt-in, headed only)
└── ...

# Darwin modules (macOS - future)
darwin/
├── aerospace.nix        # NEW - macOS tiling window manager (future)
└── ...

# Host configurations (import modules)
hosts/
├── devbox/
│   └── default.nix      # Import new NixOS modules
└── devbox-wsl/
    └── default.nix      # Import compatible modules (no Podman, no Hyprland)
```

**Structure Decision**: Follow existing flat module pattern. CLI tools extend existing Home Manager modules (`dev.nix`, `cli.nix`). New services get dedicated NixOS modules. Platform-specific desktop tools are isolated in their respective platform directories and are opt-in.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Aerospace (GUI app) violates Principle II | Future macOS support requires window management; Aerospace is the leading declarative tiling WM for macOS | No simpler alternative exists; rejecting means no macOS desktop support ever |
| Hyprland (desktop compositor) violates Principle II | Future headed NixOS requires a compositor; Hyprland is modern Wayland-native with excellent Nix support | No simpler alternative; rejecting means no headed NixOS support ever |

**Mitigation**: Both are marked as:
- Lowest priority (P3-P4)
- Platform-specific (only installed where applicable)
- Opt-in (not enabled by default)
- Isolated modules (don't affect headless configurations)

The constitution's headless-first principle applies to the *default* configuration. Platform-specific opt-in modules for future expansion are acceptable when properly isolated.