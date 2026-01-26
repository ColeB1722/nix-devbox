# Implementation Plan: Multi-Platform Development Environment

**Branch**: `009-devcontainer-orchestrator` | **Date**: 2025-01-25 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/009-devcontainer-orchestrator/spec.md`

## Summary

This feature establishes a complete multi-platform development environment ecosystem with four distinct host configurations:

1. **Orchestrator Host** (NixOS) - Headless server managing dev containers via Podman, accessible via SSH
2. **Dev Containers** (dockertools) - Remote agentic development environments with Tailscale SSH, code-server, and Zed remote
3. **macOS Workstation** (nix-darwin) - Local development with Aerospace tiling
4. **Headful NixOS Desktop** - Local development with Hyprland tiling

**nix-devbox is a reusable flake library.** It provides modules, schemas, and conventions. Consumers import it into their private repos and supply:
- User data (`users.nix` with real names, UIDs, SSH keys)
- 1Password vault name and Service Account token
- Tailscale auth keys and ACLs (in their homelab-iac)

The technical approach uses Nix flakes for declarative configuration across all platforms, dockertools for container image building, and 1Password Service Account for secrets management (single global token, not per-user logins).

## Technical Context

**Language/Version**: Nix (flakes), NixOS 25.05, nix-darwin  
**Primary Dependencies**: nixpkgs, home-manager, nixos-wsl, nix-darwin, dockertools  
**Storage**: Podman volumes for container persistence, local filesystem for workstations  
**Testing**: `nix flake check`, NixOS assertions, manual acceptance testing  
**Target Platforms**: 
- NixOS (bare-metal, WSL2) for orchestrator and headful desktop
- macOS (nix-darwin) for workstation
- OCI containers (dockertools) for dev containers

**Project Type**: Multi-platform Nix configuration (flake with multiple outputs)  
**Performance Goals**: 
- Container creation < 60 seconds
- Tailscale SSH connection < 5 seconds
- Container stop/start < 10 seconds

**Constraints**: 
- Max 7 concurrent containers globally (configurable in `users.nix`)
- Max 5 containers per user (configurable in `users.nix`)
- 2 CPU cores, 4GB RAM per container (configurable defaults)
- Auto-stop after 7 days idle, auto-destroy after 14 days stopped

**Secrets Model**:
- 1Password Service Account (single global token via `OP_SERVICE_ACCOUNT_TOKEN`)
- Per-user items: `{username}-tailscale-authkey` in consumer's vault
- Tailscale tags: `tag:devcontainer` + `tag:{username}-container` for ACL isolation

**Scale/Scope**: 
- Single orchestrator host (32GB RAM, 32 threads)
- Up to 7 concurrent dev containers
- 2 local workstation configurations (macOS, headful NixOS)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### I. Declarative Configuration ✅ PASS

| Requirement | Status | Evidence |
|-------------|--------|----------|
| All config in Nix expressions | ✅ | All hosts defined as flake outputs |
| System state reproducible from repo | ✅ | NixOS, nix-darwin, dockertools all declarative |
| No ad-hoc nix-env installations | ✅ | All packages via flake or configuration |

### II. Headless-First Design ⚠️ JUSTIFIED VIOLATION

| Requirement | Status | Evidence |
|-------------|--------|----------|
| No GUI applications | ⚠️ | Headful NixOS and macOS include GUI (Hyprland, Aerospace) |
| CLI-compatible tooling | ✅ | All tooling works via SSH/CLI |
| Non-interactive operation | ✅ | Container management fully scriptable |

**Justification**: The macOS workstation and headful NixOS desktop are *local* development environments, not the remote headless server. The constitution's rationale ("personal infrastructure for remote development") applies to the orchestrator, which remains headless. Local workstations benefit from GUI tiling for productivity.

### III. Security by Default ✅ PASS

| Requirement | Status | Evidence |
|-------------|--------|----------|
| SSH key-based auth only | ✅ | FR-002: public key authentication only |
| Tailscale primary access | ✅ | Dev containers use Tailscale SSH exclusively |
| Firewall default-deny | ✅ | Inherited from 008-extended-devtools |
| No secrets in repo | ✅ | FR-014/15: 1Password CLI for secrets, no exposure in logs |

### IV. Modular and Reusable ✅ PASS

| Requirement | Status | Evidence |
|-------------|--------|----------|
| Separate modules per concern | ✅ | Orchestrator, containers, darwin, headful as separate modules |
| Explicit dependencies | ✅ | Flake inputs, module imports documented |
| Machine-specific isolated | ✅ | hosts/ directory for machine-specific, modules for reusable |

### V. Documentation as Code ✅ PASS

| Requirement | Status | Evidence |
|-------------|--------|----------|
| Modules include comments | ✅ | Existing pattern from 008 continues |
| README quickstart | ✅ | quickstart.md generated in Phase 1 |
| Breaking changes documented | ✅ | Spec and plan capture decisions |

**Gate Result**: PASS (1 justified violation for GUI on local workstations)

## Project Structure

### Documentation (this feature)

```text
specs/009-devcontainer-orchestrator/
├── plan.md              # This file
├── spec.md              # Feature specification
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (CLI interface specs)
│   └── README.md        # CLI contract documentation
├── checklists/
│   └── requirements.md  # Specification quality checklist
└── tasks.md             # Phase 2 output
```

### Source Code (repository root)

```text
flake.nix                           # Entry point - add darwin, container outputs

# ─── Platform-Specific System Config ───────────────────────
nixos/
├── [existing modules...]
├── orchestrator.nix                # NEW: Container orchestration service
└── orchestrator-cleanup.nix        # NEW: Idle container cleanup timer

darwin/                             # NEW: nix-darwin modules
├── core.nix                        # Base darwin configuration
├── aerospace.nix                   # Aerospace tiling WM
├── cli.nix                         # CLI tools (shared with home-manager)
└── apps.nix                        # GUI applications (Obsidian, etc.)

containers/                         # NEW: dockertools definitions
├── devcontainer/
│   ├── default.nix                 # Main container image
│   ├── tailscale.nix               # Tailscale setup layer
│   ├── code-server.nix             # code-server layer
│   ├── zed-remote.nix              # Zed remote server layer
│   └── syncthing.nix               # NEW: Optional Syncthing layer for file sync
└── README.md                       # Container build documentation

# ─── Shared User Config (Home Manager) ─────────────────────
home/
├── modules/
│   ├── [existing modules...]
│   └── remote-access.nix           # NEW: code-server, zed-remote config
├── profiles/
│   ├── [existing profiles...]
│   ├── container.nix               # NEW: Profile for dev containers
│   └── workstation.nix             # NEW: Profile for local workstations
└── users/
    └── [existing users...]

# ─── Orchestrator CLI Tool ─────────────────────────────────
scripts/
└── devbox-ctl/                     # NEW: Container management CLI
    ├── devbox-ctl                  # Main entry point (bash)
    ├── create.sh                   # Container creation
    ├── destroy.sh                  # Container destruction + Tailscale cleanup
    ├── start.sh                    # Container start
    ├── stop.sh                     # Container stop
    ├── list.sh                     # List user's containers
    └── lib/
        ├── common.sh               # Shared functions
        ├── validation.sh           # Name validation, limits checking
        └── secrets.sh              # 1Password integration

# ─── Host Configurations ───────────────────────────────────
hosts/
├── devbox/                         # Existing bare-metal (add orchestrator)
│   └── default.nix
├── devbox-wsl/                     # Existing WSL2 (add orchestrator)
│   └── default.nix
├── devbox-desktop/                 # NEW: Headful NixOS
│   ├── default.nix
│   └── hardware-configuration.nix.example
└── README.md                       # Host documentation

# ─── Shared Data ───────────────────────────────────────────
lib/
├── users.nix                       # Existing user metadata
├── containers.nix                  # NEW: Container schema + conventions
└── schema.nix                      # EXTENDED: Validate containers config block

examples/
└── users.nix                       # EXTENDED: containers config with defaults
```

**Structure Decision**: Extends existing nix-devbox structure with new platform directories (`darwin/`, `containers/`) and a CLI tool (`scripts/devbox-ctl/`). Maintains flat module organization per project conventions.

## Library vs Consumer Separation

| Component | Lives In | Responsibility |
|-----------|----------|----------------|
| Modules, profiles, schemas | nix-devbox (public) | Define conventions, provide reusable config |
| `examples/users.nix` | nix-devbox (public) | Placeholder data, shows expected structure |
| `users.nix` (real data) | Consumer repo (private) | Actual users, vault name, hardware |
| Service Account token | Consumer (systemd/agenix) | Secure secret storage |
| Tailscale auth keys | Consumer (1Password) | Per-user items in their vault |
| Tailscale ACLs | Consumer (homelab-iac) | User isolation rules |

### Conventions Defined by Library

| Convention | Format | Example |
|------------|--------|---------|
| 1Password item name | `{username}-tailscale-authkey` | `coal-tailscale-authkey` |
| 1Password reference | `op://{vault}/{username}-tailscale-authkey/password` | `op://DevBox/coal-tailscale-authkey/password` |
| Tailscale tags | `tag:devcontainer`, `tag:{username}-container` | `tag:devcontainer`, `tag:coal-container` |
| Vault name | Configurable in `users.nix` | `containers.opVault = "DevBox"` |

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| GUI on local workstations | Local productivity requires tiling WM | CLI-only local dev is impractical for daily use |
| 4 host configurations | Each serves distinct use case (remote container, remote orchestrator, local macOS, local Linux) | Fewer configs would force users into suboptimal workflows |
| Separate CLI tool (devbox-ctl) | Container lifecycle needs user-facing interface with validation, limits enforcement | Direct podman commands lack user isolation, validation, secrets integration |

## Phase 0 Research Topics

1. **dockertools patterns** - Best practices for building OCI images with Nix dockertools
2. **Tailscale in containers** - Running Tailscale daemon inside rootless Podman containers
3. **nix-darwin setup** - Module structure and home-manager integration for macOS
4. **Aerospace configuration** - Nix-based Aerospace tiling WM setup
5. **1Password CLI integration** - Secure secret retrieval patterns for container creation
6. **Podman systemd integration** - Auto-restart containers, resource limits, cleanup timers
7. **Zed remote server** - Packaging and configuration for remote Zed connections
8. **Syncthing in containers** - Running Syncthing inside containers for bidirectional file sync with local workstations over Tailscale

## Phase 1 Design Outputs

- `research.md` - Consolidated findings from Phase 0
- `data-model.md` - Entity definitions (Container, User, ContainerImage, etc.)
- `contracts/README.md` - CLI interface specification for devbox-ctl
- `quickstart.md` - Deployment and usage guide for all 4 host configurations