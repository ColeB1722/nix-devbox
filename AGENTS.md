# nix-devbox Development Guidelines

Auto-generated from all feature plans. Last updated: 2026-01-18

## Active Technologies
- Nix (flakes format, NixOS 24.05+) + git-hooks.nix (cachix), nixfmt, statix, deadnix (002-testing-infrastructure)
- N/A (configuration files only) (002-testing-infrastructure)
- Nix (flakes format, NixOS 25.05) + Home Manager 25.05, nixpkgs 25.05, existing modules from feature 001 (005-devtools-config)
- Nix (flakes format, NixOS 25.05) + NixOS modules, Home Manager 25.05, existing modules from features 001/005 (006-multi-user-support)
- N/A (filesystem-based user home directories) (006-multi-user-support)

- Nix (flakes format, NixOS 24.05+) + NixOS modules, Home Manager, Tailscale (001-devbox-skeleton)

## Project Structure

```text
flake.nix                    # Flake entry point with inputs/outputs
flake.lock                   # Pinned dependency versions
justfile                     # Task runner (just) for common commands
.gitignore                   # Git ignore rules
.github/workflows/ci.yml     # GitHub Actions CI workflow

hosts/
├── devbox/                  # Bare-metal/VM configuration
│   ├── default.nix          # Machine-specific configuration
│   └── hardware-configuration.nix  # Generated hardware config (gitignored)
└── devbox-wsl/              # WSL2 configuration
    └── default.nix          # WSL-specific settings

modules/
├── core/
│   └── default.nix          # Base system settings (locale, timezone, nix)
├── networking/
│   ├── default.nix          # Firewall configuration (bare-metal only)
│   └── tailscale.nix        # Tailscale VPN service (bare-metal only)
├── security/
│   └── ssh.nix              # SSH hardening
├── user/
│   └── default.nix          # Multi-user accounts (coal, violino) with hardcoded SSH public keys
├── shell/
│   └── default.nix          # Fish shell system configuration (feature 005)
├── docker/
│   └── default.nix          # Docker container runtime (feature 005)
└── services/
    └── code-server.nix      # Per-user code-server instances (coal:8080, violino:8081)

home/
├── common.nix               # Shared Home Manager config (all users inherit this)
├── coal.nix                 # coal's personal config (admin user, uid=1000)
├── violino.nix              # violino's personal config (dev user, uid=1001)
└── default.nix              # Entry point (imports coal.nix for backwards compat)

specs/                       # Feature specifications (speckit)
```

## Commands

Use `just` for common tasks (run `just` to see all available targets):

```bash
# Development
just develop          # Enter dev shell with pre-commit hooks
just check            # Run all flake checks
just build            # Build NixOS configuration
just fmt              # Format all Nix files
just lint             # Run linters (statix + deadnix)

# Deployment (on target machine)
just deploy           # Deploy configuration
just rollback         # Rollback to previous generation

# Maintenance
just update           # Update all flake inputs
just gc               # Garbage collect (older than 30 days)
```

Or use nix commands directly:

```bash
nix flake check                              # Validate flake
nixos-rebuild build --flake .#devbox         # Build without deploying
sudo nixos-rebuild switch --flake .#devbox   # Deploy to current machine
nix flake update                             # Update flake inputs
```

## WSL Deployment

For deploying to Windows Subsystem for Linux, see `specs/003-wsl-support/quickstart.md`.

Quick reference:
```bash
# Inside WSL after cloning the repo
sudo nixos-rebuild switch --flake .#devbox-wsl

# Or pull from FlakeHub
sudo nixos-rebuild switch --flake flakehub:coal-bap/nix-devbox#devbox-wsl
```

Key differences from bare-metal:
- No hardware-configuration.nix needed
- Tailscale runs on Windows host, not in WSL
- SSH is exposed directly (Windows + Tailscale handles filtering)

## Code Style

- **Nix files**: 2-space indentation, inline comments for non-obvious decisions
- **Module pattern**: Use `lib.mkDefault` for overridable defaults
- **Constitution**: All changes must align with `.specify/memory/constitution.md`

## Module Documentation

Each module includes:
1. Header comment explaining purpose and constitution alignment
2. Security model documentation (for security-relevant modules)
3. Usage instructions and customization notes

## Security

### Pre-commit Security Hooks

The following security checks run on every commit:
- **gitleaks**: Scans for secrets, API keys, and credentials
- **detect-private-key**: Blocks commits containing private keys
- **check-ssh-keys**: Verifies only safe SSH key patterns are committed

### NixOS Assertions

The following security properties are enforced via NixOS assertions:
- Firewall MUST be enabled (modules/networking/default.nix)
- SSH password authentication MUST be disabled (modules/security/ssh.nix)
- SSH root login MUST be denied (modules/security/ssh.nix)
- User MUST have at least one valid SSH key (modules/user/default.nix)

### Public Repository Safety

This repo is designed to be safely public:
- No secrets or credentials committed
- SSH keys are either CI test keys (no private key) or placeholders
- Pre-commit hooks prevent accidental secret commits
- Hardware-specific configs are gitignored

## Service Access

### code-server (Browser-based VS Code)

Access is controlled by Tailscale ACLs defined in `homelab-iac/tailscale/main.tf`.

| User | Port | Access URL |
|------|------|------------|
| coal (admin) | 8080 | `http://devbox:8080` |
| violino (user) | 8081 | `http://devbox:8081` |

**Access model:**
- coal (admin): Can access both 8080 and 8081 (for troubleshooting)
- violino (user): Can only access 8081 (their own instance)

**Requirements:**
- Device must be on the Tailscale network
- User must have appropriate ACL permissions in homelab-iac

**To modify access permissions:** Edit `homelab-iac/tailscale/main.tf`

## Recent Changes
- 006-multi-user-support: Added Nix (flakes format, NixOS 25.05) + NixOS modules, Home Manager 25.05, existing modules from features 001/005
- 005-devtools-config: Added Nix (flakes format, NixOS 25.05) + Home Manager 25.05, nixpkgs 25.05, existing modules from feature 001
- 002-testing-infrastructure: Added Nix (flakes format, NixOS 24.05+) + git-hooks.nix (cachix), nixfmt, statix, deadnix


<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
