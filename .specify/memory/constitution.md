<!--
=============================================================================
SYNC IMPACT REPORT
=============================================================================
Version change: N/A (initial) → 1.0.0
Modified principles: N/A (initial ratification)
Added sections:
  - Core Principles (5 principles)
  - Technology Constraints
  - Development Workflow
  - Governance
Removed sections: N/A (initial)
Templates requiring updates:
  - .specify/templates/plan-template.md: ✅ Compatible (Constitution Check section generic)
  - .specify/templates/spec-template.md: ✅ Compatible (no constitution-specific references)
  - .specify/templates/tasks-template.md: ✅ Compatible (no constitution-specific references)
Follow-up TODOs: None
=============================================================================
-->

# nix-devbox Constitution

## Core Principles

### I. Declarative Configuration

All system configuration MUST be declaratively defined in Nix expressions. No imperative
system modifications are permitted outside of Nix management.

- Every installed package, service, and configuration MUST be tracked in version control
- System state MUST be reproducible from repository contents alone
- Ad-hoc `nix-env -i` installations are prohibited; use flakes or configuration.nix

**Rationale**: Reproducibility is the core value proposition. If configuration cannot be
rebuilt identically on a fresh machine, the devbox loses its primary purpose.

### II. Headless-First Design

The devbox is a remote, headless server. All tooling MUST be CLI-compatible and
SSH-accessible.

- No GUI applications or desktop environments SHALL be installed
- All configuration MUST be manageable via terminal (SSH/Tailscale)
- Interactive tools MUST support non-interactive/scripted operation where feasible

**Rationale**: This is personal infrastructure for remote development. GUI overhead
wastes resources and complicates remote access.

### III. Security by Default

Remote access requires defense in depth. Security configuration MUST NOT be
weakened for convenience.

- SSH MUST use key-based authentication only; password auth is prohibited
- Tailscale MUST be the primary network access method; minimize public exposure
- Firewall rules MUST default-deny; explicitly allow only required services
- Secrets MUST NOT be committed to the repository; use agenix, sops-nix, or equivalent

**Rationale**: A self-hosted remote machine is an attack surface. Security lapses
compound when the machine hosts development credentials and workflows.

### IV. Modular and Reusable

Configuration MUST be organized into composable modules for reuse across machines
or projects.

- Each logical concern (e.g., shell, editor, language toolchain) SHOULD be a separate module
- Modules MUST declare their dependencies explicitly
- Machine-specific overrides MUST be isolated from reusable module definitions

**Rationale**: The goal is a portable devbox. Monolithic configuration defeats
reusability and increases maintenance burden.

### V. Documentation as Code

Configuration MUST be self-documenting. Users (including future-you) MUST be able
to understand and modify the system without external tribal knowledge.

- Each module MUST include comments explaining non-obvious decisions
- README MUST provide quickstart instructions sufficient for fresh deployment
- Breaking changes MUST be documented in commit messages or a changelog

**Rationale**: Personal infrastructure often suffers from "works on my machine" syndrome.
Documentation ensures the devbox remains useful months or years later.

## Technology Constraints

**Platform**: NixOS (primary) or Nix on Linux (Darwin support is out of scope for server)
**Access Methods**: SSH, Tailscale
**Configuration Format**: Nix flakes (preferred) or classic Nix expressions
**Secret Management**: agenix, sops-nix, or environment-variable injection at runtime

Prohibited:
- Ansible, Puppet, Chef, or other non-Nix configuration management overlays
- Docker for services that can be natively managed by NixOS modules
- Manual system configuration not captured in Nix

## Development Workflow

1. **Branch for changes**: Feature branches for non-trivial modifications
2. **Test locally**: Use `nixos-rebuild build` or `nix build` before deployment
3. **Deploy incrementally**: Use `nixos-rebuild switch` with rollback awareness
4. **Document decisions**: Update comments or README when adding/changing modules

**Rollback Protocol**: If a deployment breaks the system, use `nixos-rebuild switch
--rollback` or boot into a previous generation from the bootloader.

## Governance

This constitution governs all contributions to the nix-devbox repository.

- Amendments require updating this document with rationale and version bump
- Version follows semantic versioning:
  - MAJOR: Principle removal or redefinition
  - MINOR: New principle or section added
  - PATCH: Clarifications or typo fixes
- Compliance is self-enforced (personal repo); periodic review recommended quarterly

**Version**: 1.0.0 | **Ratified**: 2026-01-17 | **Last Amended**: 2026-01-17
