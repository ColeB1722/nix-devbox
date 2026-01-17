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

```bash
# Validate flake structure
nix flake check

# Build without deploying (test configuration)
nixos-rebuild build --flake .#devbox

# Deploy to current machine
sudo nixos-rebuild switch --flake .#devbox

# Rollback to previous generation
sudo nixos-rebuild switch --rollback

# Update flake inputs
nix flake update

# Show flake outputs
nix flake show
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

## Security Assertions

The following security properties are enforced via NixOS assertions:
- Firewall MUST be enabled (modules/networking/default.nix)
- SSH password authentication MUST be disabled (modules/security/ssh.nix)
- SSH root login MUST be denied (modules/security/ssh.nix)
- User MUST have at least one SSH key (modules/user/default.nix)

## Recent Changes
- 002-testing-infrastructure: Added Nix (flakes format, NixOS 24.05+) + git-hooks.nix (cachix), nixfmt, statix, deadnix

- 001-devbox-skeleton: Implemented complete NixOS flake structure with modular architecture

<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
