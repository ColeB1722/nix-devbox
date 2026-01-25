# nix-devbox

A minimal, secure, modular Nix configuration for self-hosted development machines. Supports NixOS (bare-metal, WSL), with planned support for macOS (nix-darwin) and containers (dockertools).

## Overview

This repository contains configurations for:
- **devbox**: Bare-metal/VM development server (NixOS)
- **devbox-wsl**: Windows Subsystem for Linux variant (NixOS)
- **macOS**: Planned via nix-darwin
- **Containers**: Planned via dockertools

All configurations share a common CLI toolkit via Home Manager while using platform-specific system modules.

## Features

- **Multi-user support**: Separate accounts for `coal` (admin) and `violino` (dev user)
- **Per-user code-server**: Browser-based VS Code on ports 8080/8081
- **Modern shell**: Fish with fzf, bat, eza, and smart abbreviations
- **Development tools**: neovim, lazygit, zellij, direnv, Docker
- **AI coding tools**: OpenCode, Claude Code
- **Infrastructure**: Terraform, 1Password CLI, GitHub CLI
- **Security**: SSH key-only auth, Tailscale-only access, firewall enabled

## Quick Start

### Local Deployment (on the devbox)

```bash
# Clone and deploy
git clone https://github.com/ColeB1722/nix-devbox.git
cd nix-devbox

# For bare-metal/VM
sudo nixos-rebuild switch --flake .#devbox

# For WSL
sudo nixos-rebuild switch --flake .#devbox-wsl
```

### FlakeHub Direct (no git clone)

```bash
sudo nixos-rebuild switch --flake 'https://flakehub.com/f/coal-bap/nix-devbox/*#devbox'
```

## Development

```bash
# Enter dev shell with pre-commit hooks
just develop

# Run checks
just check

# Format code
just fmt

# Build without deploying
just build

# See all targets
just
```

## Project Structure

```
flake.nix                    # Flake entry point

nixos/                       # NixOS system modules (flat structure)
├── core.nix                 # Base system (locale, timezone, nix)
├── firewall.nix             # Firewall configuration
├── tailscale.nix            # Tailscale VPN service
├── ssh.nix                  # SSH hardening
├── fish.nix                 # Fish shell (system-level)
├── docker.nix               # Container runtime
├── users.nix                # User accounts + Home Manager
└── code-server.nix          # Per-user code-server instances

darwin/                      # nix-darwin modules (planned)

containers/                  # dockertools builds (planned)

home/                        # Home Manager configuration (shared across platforms)
├── modules/                 # Reusable building blocks
│   ├── cli.nix              # Core CLI tools (bat, eza, fzf, etc.)
│   ├── fish.nix             # Fish shell config
│   ├── git.nix              # Git + lazygit + gh
│   └── dev.nix              # Dev tools (neovim, zellij, AI tools)
├── profiles/                # Composable bundles
│   ├── minimal.nix          # cli + fish + git
│   └── developer.nix        # minimal + dev tools
└── users/                   # Per-user configs
    ├── coal.nix             # Admin user
    └── violino.nix          # Dev user

lib/                         # Shared data
└── users.nix                # User metadata (SSH keys, UIDs, etc.)

hosts/                       # Machine-specific configurations
├── devbox/                  # Bare-metal/VM
└── devbox-wsl/              # WSL2
```

## Architecture

The configuration is organized around three key principles:

1. **Platform separation**: NixOS and Darwin modules are fundamentally different, so each gets its own directory (`nixos/`, `darwin/`).

2. **Home Manager as shared layer**: User-level config in `home/` works across all platforms. This is where the common CLI toolkit lives.

3. **Centralized user data**: SSH keys, UIDs, and metadata live in `lib/users.nix` and are consumed by platform-specific modules.

## Adding/Updating SSH Keys

SSH public keys are stored in `lib/users.nix`. To update:

```nix
# lib/users.nix
coal = {
  # ...
  sshKeys = [
    "ssh-ed25519 AAAA... your-key-comment"
  ];
};
```

Public keys are safe to commit—only private keys must be kept secret.

## Platform Support

| Platform | Status | Directory |
|----------|--------|-----------|
| NixOS (bare-metal) | ✅ Implemented | `nixos/`, `hosts/devbox/` |
| NixOS (WSL) | ✅ Implemented | `nixos/`, `hosts/devbox-wsl/` |
| macOS (nix-darwin) | 🚧 Planned | `darwin/` |
| Containers | 🚧 Planned | `containers/` |

## Resources

- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Home Manager](https://github.com/nix-community/home-manager)
- [nix-darwin](https://github.com/LnL7/nix-darwin)
- [FlakeHub](https://flakehub.com/flake/coal-bap/nix-devbox)