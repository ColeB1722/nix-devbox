# nix-devbox Development Guidelines

Auto-generated from all feature plans. Last updated: 2026-01-17

## Active Technologies
- Nix (flakes format, NixOS 24.05+) + git-hooks.nix (cachix), nixfmt, statix, deadnix (002-testing-infrastructure)
- N/A (configuration files only) (002-testing-infrastructure)

- Nix (flakes format, NixOS 24.05+) + NixOS modules, Home Manager, Tailscale (001-devbox-skeleton)

## Project Structure

```text
flake.nix                    # Flake entry point with inputs/outputs
flake.lock                   # Pinned dependency versions
justfile                     # Task runner (just) for common commands
.gitignore                   # Git ignore rules
.github/workflows/ci.yml     # GitHub Actions CI workflow

hosts/
└── devbox/
    ├── default.nix          # Machine-specific configuration
    └── hardware-configuration.nix  # Generated hardware config (gitignored)

modules/
├── core/
│   └── default.nix          # Base system settings (locale, timezone, nix)
├── networking/
│   ├── default.nix          # Firewall configuration
│   └── tailscale.nix        # Tailscale VPN service
├── security/
│   └── ssh.nix              # SSH hardening
└── user/
    └── default.nix          # User account and Home Manager

home/
└── default.nix              # Home Manager user environment

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

## Recent Changes
- 002-testing-infrastructure: Added Nix (flakes format, NixOS 24.05+) + git-hooks.nix (cachix), nixfmt, statix, deadnix

- 001-devbox-skeleton: Implemented complete NixOS flake structure with modular architecture

<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
