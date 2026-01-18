# nix-devbox

A minimal, secure, modular NixOS configuration for a self-hosted remote development machine. Access via SSH over Tailscale only.

## Overview

This repository contains NixOS configurations for:
- **devbox**: Bare-metal/VM development server
- **devbox-wsl**: Windows Subsystem for Linux variant

Both configurations provide a consistent, declarative development environment with modern CLI tools, multi-user support, and secure remote access.

## Features

- **Multi-user support**: Separate accounts for `coal` (admin) and `violino` (user)
- **Per-user code-server**: Browser-based VS Code on ports 8080/8081
- **Modern shell**: Fish with fzf, bat, eza, and smart abbreviations
- **Development tools**: neovim, lazygit, zellij, direnv, Docker
- **AI coding tools**: OpenCode, Claude Code
- **Infrastructure**: Terraform, 1Password CLI, GitHub CLI
- **Security**: SSH key-only auth, Tailscale-only access, firewall enabled

## Quick Start

### Remote Deployment (from your machine)

Deploy the latest version from FlakeHub to a remote devbox:

```bash
# Deploy without reboot
just deploy-remote

# Deploy and reboot on success
just deploy-remote-reboot

# Deploy to specific host/config
just deploy-remote devbox-wsl devbox-wsl
```

Requires: Tailscale connection and SSH access to target host.

### Local Deployment (on the devbox)

```bash
# Clone and deploy with SSH keys
git clone https://github.com/ColeB1722/nix-devbox.git
cd nix-devbox
cp .env.example .env
# Edit .env with your SSH public keys
source .env
sudo -E nixos-rebuild switch --flake .#devbox
```

### FlakeHub Direct (no git clone)

```bash
# On the devbox itself
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

# See all targets
just
```

## Project Structure

```
flake.nix                    # Flake entry point
hosts/
├── devbox/                  # Bare-metal configuration
└── devbox-wsl/              # WSL2 configuration
modules/
├── core/                    # Base system (locale, timezone, nix)
├── networking/              # Firewall, Tailscale
├── security/                # SSH hardening
├── user/                    # Multi-user accounts
├── shell/                   # Fish shell
├── docker/                  # Container runtime
└── services/                # code-server
home/
├── common.nix               # Shared Home Manager config
├── coal.nix                 # coal's personal config
└── violino.nix              # violino's personal config
```

## SSH Keys

SSH public keys are hardcoded in `modules/user/default.nix`. This is safe because public keys are designed to be shared—only private keys must be kept secret.

To add or update a user's key, edit the `coalKey` or `violinoKey` variables in that module.

## Resources

- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Home Manager](https://github.com/nix-community/home-manager)
- [FlakeHub](https://flakehub.com/flake/coal-bap/nix-devbox)
