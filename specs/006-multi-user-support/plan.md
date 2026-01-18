# Implementation Plan: Multi-User Support

**Branch**: `006-multi-user-support` | **Date**: 2026-01-18 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/006-multi-user-support/spec.md`

## Summary

Enable the NixOS devbox to support multiple users (Cole as admin, Violino as secondary user) with:
- Separate user accounts with isolated home directories
- SSH public keys injected via environment variables at build time
- Per-user Home Manager configurations
- Per-user code-server instances on dedicated ports (8080, 8081)
- Shared docker access for both users

## Technical Context

**Language/Version**: Nix (flakes format, NixOS 25.05)  
**Primary Dependencies**: NixOS modules, Home Manager 25.05, existing modules from features 001/005  
**Storage**: N/A (filesystem-based user home directories)  
**Testing**: `nix flake check`, NixOS assertions, manual SSH verification  
**Target Platform**: NixOS (bare-metal devbox, WSL2 devbox-wsl)  
**Project Type**: NixOS configuration (modular Nix expressions)  
**Performance Goals**: N/A (standard multi-user system)  
**Constraints**: SSH keys must be injected via env vars, not hardcoded; CI publish job must not have key secrets  
**Scale/Scope**: 2 users (Cole, Violino), extensible to additional users via configuration

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Evidence |
|-----------|--------|----------|
| I. Declarative Configuration | ✅ PASS | All user accounts, SSH keys, and Home Manager configs defined in Nix |
| II. Headless-First Design | ✅ PASS | SSH-only access, code-server for browser IDE, no GUI |
| III. Security by Default | ✅ PASS | SSH key-only auth, env var injection (no hardcoded keys), per-user isolation |
| IV. Modular and Reusable | ✅ PASS | User module refactored to support multiple users declaratively |
| V. Documentation as Code | ✅ PASS | Inline comments, quickstart.md for deployment |

**Gate Result**: PASS - No violations. Proceeding to Phase 0.

## Project Structure

### Documentation (this feature)

```text
specs/006-multi-user-support/
├── spec.md              # Feature specification
├── plan.md              # This file
├── research.md          # Phase 0 output - technical research
├── data-model.md        # Phase 1 output - user/config entities
├── quickstart.md        # Phase 1 output - deployment guide
├── contracts/           # Phase 1 output - module interfaces
│   └── module-interfaces.md
└── tasks.md             # Phase 2 output (created by /speckit.tasks)
```

### Source Code (repository root)

```text
flake.nix                    # Flake entry - no changes expected
modules/
├── user/
│   └── default.nix          # MAJOR REFACTOR: Multi-user support with env var key injection
├── services/
│   └── code-server.nix      # UPDATE: Per-user instances on separate ports
└── ...                      # Other modules unchanged

home/
├── common.nix               # NEW: Shared Home Manager config (base tools)
├── cole.nix                 # NEW: Cole's personal config (git identity, etc.)
├── violino.nix              # NEW: Violino's personal config
└── default.nix              # REFACTOR: Entry point that imports per-user configs

hosts/
├── devbox/default.nix       # UPDATE: Import multi-user module
└── devbox-wsl/default.nix   # UPDATE: Import multi-user module
```

**Structure Decision**: Refactor existing modules in-place. Create per-user Home Manager configs under `home/`. No new top-level directories needed.

## Constitution Check (Post-Design)

*Re-evaluation after Phase 1 design completion.*

| Principle | Status | Post-Design Evidence |
|-----------|--------|----------------------|
| I. Declarative Configuration | ✅ PASS | User module, Home Manager configs, systemd services all in Nix |
| II. Headless-First Design | ✅ PASS | All access via SSH/Tailscale; code-server for browser IDE |
| III. Security by Default | ✅ PASS | SSH key-only auth; env var injection keeps keys out of repo; per-user isolation via Unix permissions |
| IV. Modular and Reusable | ✅ PASS | common.nix shared across users; per-user configs import shared module |
| V. Documentation as Code | ✅ PASS | quickstart.md, module-interfaces.md, inline comments planned |

**Post-Design Gate Result**: PASS - Design aligns with all constitution principles.

## Complexity Tracking

No constitution violations. No complexity justifications needed.

## Implementation Phases

### Phase 0: Research (Complete)
See [research.md](./research.md) for:
- Environment variable injection patterns in Nix
- Multi-user Home Manager configuration patterns
- Per-user systemd services (code-server)

### Phase 1: Design (Complete)
See:
- [data-model.md](./data-model.md) - User entities and configuration structure
- [contracts/module-interfaces.md](./contracts/module-interfaces.md) - Module interfaces
- [quickstart.md](./quickstart.md) - Deployment guide

### Phase 2: Tasks (Next)
Run `/speckit.tasks` to generate implementation tasks from this plan.
