# Implementation Plan: Container Host

**Branch**: `011-container-host` | **Date**: 2025-01-31 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/011-container-host/spec.md`

## Summary

Specialize the `devbox` host into a lean, secure container management platform. Key features:
- Tailscale SSH with OAuth authentication (no committed SSH keys)
- Rootless Podman with per-user isolation and resource quotas
- Minimal attack surface (no web UIs, strict firewall)
- Admin oversight capabilities for multi-tenant container workloads

## Technical Context

**Language/Version**: Nix (NixOS 25.05)
**Primary Dependencies**: Podman (rootless), Tailscale, systemd (cgroups v2)
**Storage**: Filesystem quotas (ext4/xfs/btrfs) for per-user container storage limits
**Testing**: NixOS VM tests, manual Tailscale ACL verification
**Target Platform**: NixOS x86_64-linux (bare-metal/VM)
**Project Type**: NixOS module configuration
**Performance Goals**: SSH connection <5s, container launch <60s for new users
**Constraints**: <15 system services, 0 non-Tailscale connections accepted
**Scale/Scope**: Multi-user (2-10 users), each running 1-5 agent containers

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Pre-Design Check

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Declarative Configuration | ✅ PASS | All config in Nix modules; no imperative setup |
| II. Headless-First Design | ✅ PASS | No GUI; SSH-only access; CLI container management |
| III. Security by Default | ✅ PASS | Tailscale-only access, OAuth auth, rootless containers, default-deny firewall |
| IV. Modular and Reusable | ✅ PASS | New host variant `hosts/container-host/`; reuses existing modules |
| V. Documentation as Code | ✅ PASS | Inline comments; quickstart in spec |

**Technology Constraints Check**:
- ✅ Platform: NixOS
- ✅ Access: Tailscale SSH
- ✅ Config: Nix flakes
- ✅ No prohibited tools (Ansible, Docker-for-services, manual config)

**Gate Status**: PASS — Proceed to Phase 0

### Post-Design Re-Check (After Phase 1)

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Declarative Configuration | ✅ PASS | New modules (`tailscale-ssh.nix`, `podman-isolation.nix`) are pure Nix; resource quotas declared in `users.nix` |
| II. Headless-First Design | ✅ PASS | No GUI components added; all admin/user interaction via SSH + CLI |
| III. Security by Default | ✅ PASS | Design enforces: OAuth-only auth, rootless containers, no `--privileged`, user namespace isolation, filesystem quotas |
| IV. Modular and Reusable | ✅ PASS | Schema extension (`resourceQuota`) is optional; existing hosts unaffected; new host reuses existing modules |
| V. Documentation as Code | ✅ PASS | `quickstart.md` covers deployment, user guide, admin guide, troubleshooting |

**Post-Design Gate Status**: PASS — Proceed to Phase 2 (tasks)

## Project Structure

### Documentation (this feature)

```text
specs/011-container-host/
├── spec.md              # Feature specification
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (N/A - no API)
└── tasks.md             # Phase 2 output
```

### Source Code (repository root)

```text
hosts/
└── container-host/
    └── default.nix      # New host definition

nixos/
├── tailscale-ssh.nix    # NEW: Tailscale SSH OAuth config
├── podman-isolation.nix # NEW: Per-user rootless Podman with quotas
├── podman.nix           # MODIFY: Add isolation options
└── users.nix            # MODIFY: Add resource quota fields to user schema

lib/
└── schema.nix           # MODIFY: Add resourceQuota validation

home/
└── modules/
    └── podman-user.nix  # NEW: User-level Podman configuration
```

**Structure Decision**: Extends existing flat module structure. New host `container-host` imports a subset of existing modules plus new isolation-focused modules. No new directories beyond the host definition.

## Complexity Tracking

No constitution violations requiring justification.