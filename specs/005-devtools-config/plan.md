# Implementation Plan: Development Tools and Configuration

**Branch**: `005-devtools-config` | **Date**: 2026-01-18 | **Spec**: [spec.md](./spec.md)  
**Input**: Feature specification from `/specs/005-devtools-config/spec.md`

## Summary

Enrich the foundational NixOS devbox with a comprehensive development toolset including:
- Fish shell as default with modern CLI tools (fzf, bat, eza, fd, ripgrep, tree)
- Docker container runtime with user permissions
- AI coding tools (OpenCode, Claude Code)
- Remote IDE access (code-server, Zed remote server)
- Terminal multiplexer (zellij)
- Version control tools (lazygit, gh)
- Package managers (npm, uv)
- Infrastructure tools (terraform, 1Password CLI)
- CodeRabbit integration documentation

Technical approach: All tools installed via nixpkgs packages; new NixOS modules for Docker and code-server; Home Manager for user-level tool configuration.

## Technical Context

**Language/Version**: Nix (flakes format, NixOS 25.05)  
**Primary Dependencies**: Home Manager 25.05, nixpkgs 25.05, existing modules from feature 001  
**Storage**: N/A (configuration files only)  
**Testing**: `nix flake check`, existing pre-commit hooks (nixfmt, statix, deadnix)  
**Target Platform**: NixOS x86_64-linux (bare-metal and WSL)  
**Project Type**: NixOS configuration (module-based)  
**Performance Goals**: Shell startup < 500ms, code-server response < 1s  
**Constraints**: Headless-only (no GUI), Tailscale-only remote access, unfree packages allowed for specific tools  
**Scale/Scope**: Single user devbox, ~20 new tools/configurations

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| **I. Declarative Configuration** | PASS | All tools via nixpkgs/Home Manager, no imperative installs |
| **II. Headless-First Design** | PASS | All tools CLI-compatible, code-server is browser-based (no GUI on server) |
| **III. Security by Default** | PASS | code-server binds localhost only, Tailscale for access, no public exposure |
| **IV. Modular and Reusable** | PASS | New modules in separate files, clear dependencies |
| **V. Documentation as Code** | PASS | Each module has header comments, quickstart provided |

### Technology Constraints Check

| Constraint | Status | Notes |
|------------|--------|-------|
| NixOS platform | PASS | Target is NixOS |
| SSH/Tailscale access | PASS | code-server via Tailscale |
| Nix flakes format | PASS | Existing flake structure preserved |
| No Ansible/Puppet/Chef | PASS | Pure Nix |
| Docker only where needed | PASS | Docker for container workflows, not NixOS services |
| No manual configuration | PASS | All config in Nix |

### Post-Design Re-check (Phase 1)

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Declarative | PASS | All packages and services declaratively defined |
| II. Headless-First | PASS | No GUI packages, code-server is remote browser access |
| III. Security | PASS | code-server localhost-only, user in docker group (not root) |
| IV. Modular | PASS | 3 new modules, clear separation |
| V. Documentation | PASS | Module headers, quickstart.md, contracts documented |

## Project Structure

### Documentation (this feature)

```text
specs/005-devtools-config/
├── plan.md              # This file
├── research.md          # Package research and decisions
├── data-model.md        # Configuration structure
├── quickstart.md        # Deployment and verification guide
├── contracts/           # Module interfaces
│   └── module-interfaces.md
├── checklists/
│   └── requirements.md  # Spec quality checklist
└── tasks.md             # Phase 2 output (NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
# NixOS Configuration Structure

flake.nix                    # Flake entry (existing, may need unfree config)
flake.lock                   # Dependencies (existing)

hosts/
├── devbox/
│   └── default.nix          # Add imports for new modules
└── devbox-wsl/
    └── default.nix          # Add imports (excluding Docker)

modules/
├── core/
│   └── default.nix          # Existing
├── networking/
│   ├── default.nix          # Existing
│   └── tailscale.nix        # Existing
├── security/
│   └── ssh.nix              # Existing
├── user/
│   └── default.nix          # Modify: add docker group, set fish shell
├── shell/                   # NEW
│   └── default.nix          # Fish system-level config
├── docker/                  # NEW
│   └── default.nix          # Docker daemon and permissions
└── services/                # NEW
    └── code-server.nix      # code-server web IDE

home/
└── default.nix              # Extend: fish, fzf, tools, zellij, etc.
```

**Structure Decision**: Extends existing modular NixOS structure from feature 001. Three new module directories (`shell/`, `docker/`, `services/`) follow Constitution Principle IV. User tools in Home Manager follow existing pattern.

## Implementation Order

### Phase 1: Core Shell Environment (P1)

1. Create `modules/shell/default.nix` - Fish system config
2. Update `modules/user/default.nix` - Set fish as shell, add docker group
3. Extend `home/default.nix` - Fish config, fzf, CLI tools

### Phase 2: Container Runtime (P1)

4. Create `modules/docker/default.nix` - Docker daemon
5. Update host imports

### Phase 3: Development Tools (P2)

6. Add AI tools to Home Manager (opencode, claude-code)
7. Create `modules/services/code-server.nix`
8. Add Zed remote server to Home Manager
9. Add zellij, lazygit configurations

### Phase 4: Package Managers & IaC (P2/P3)

10. Add npm (nodejs), uv to Home Manager
11. Add terraform to Home Manager
12. Add 1Password CLI (configure programs._1password)

### Phase 5: Documentation & Finalization (P3)

13. CodeRabbit documentation
14. Update AGENTS.md
15. Verification testing

## Complexity Tracking

> No constitution violations to justify. All design decisions align with principles.

## Dependencies

| Dependency | Version | Source | Notes |
|------------|---------|--------|-------|
| fish | nixpkgs | `pkgs.fish` | Programs module |
| docker | nixpkgs | `virtualisation.docker` | NixOS module |
| code-server | nixpkgs | `services.code-server` | NixOS module |
| zed-editor.remote_server | nixpkgs-unstable | `pkgs.zed-editor.remote_server` | May need overlay for 24.11 |
| opencode | nixpkgs | `pkgs.opencode` | MIT license |
| claude-code | nixpkgs | `pkgs.claude-code` | Unfree |
| _1password-cli | nixpkgs | `pkgs._1password-cli` | Unfree |
| terraform | nixpkgs | `pkgs.terraform` | BSL license |

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Zed remote server not in stable nixpkgs | Medium | Use overlay or nixpkgs-unstable for zed-editor |
| Unfree packages blocked | Low | Document allowUnfree configuration |
| Docker on WSL conflicts | Medium | Conditionally disable Docker module on WSL |
| code-server port conflicts | Low | Use non-standard port (8080) |
| Shell startup slow with many tools | Low | Lazy-load where possible, test startup time |
