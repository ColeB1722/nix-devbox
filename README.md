# nix-devbox

A minimal, secure, modular Nix configuration for self-hosted development machines. Supports NixOS (bare-metal, WSL, headful desktop), macOS (nix-darwin), and containers (dockertools).

## Overview

This repository contains configurations for:
- **devbox**: Bare-metal/VM development server with container orchestrator (NixOS)
- **devbox-wsl**: Windows Subsystem for Linux variant (NixOS)
- **devbox-desktop**: Headful workstation with Hyprland compositor (NixOS)
- **macbook**: macOS workstation with Aerospace tiling WM (nix-darwin)
- **devcontainer**: OCI container images for dev environments (dockertools)

All configurations share a common CLI toolkit via Home Manager while using platform-specific system modules.

## Features

- **Multi-user support**: Separate accounts for `coal` (admin) and `violino` (dev user)
- **Per-user code-server**: Browser-based VS Code on ports 8080/8081
- **Modern shell**: Fish with fzf, bat, eza, yazi, and smart abbreviations
- **Development tools**: neovim, lazygit, zellij, direnv, Rust toolchain
- **AI coding tools**: goose-cli, Claude Code
- **Container orchestrator**: Podman-based dev containers with `devbox-ctl` CLI
- **File sync**: Syncthing integration for containers
- **Remote access**: ttyd web terminal, code-server, Zed remote
- **Desktop**: Hyprland compositor (NixOS), Aerospace tiling WM (macOS)
- **Infrastructure**: Terraform, 1Password CLI, GitHub CLI
- **Security**: SSH key-only auth, Tailscale-only access, firewall enabled

## Quick Start

### Local Deployment (on the target machine)

```bash
# Clone and deploy
git clone https://github.com/colebateman/nix-devbox.git
cd nix-devbox

# For bare-metal/VM (orchestrator host)
sudo nixos-rebuild switch --flake .#devbox

# For WSL
sudo nixos-rebuild switch --flake .#devbox-wsl

# For headful desktop with Hyprland
sudo nixos-rebuild switch --flake .#devbox-desktop

# For macOS (first time - bootstrap nix-darwin)
nix run nix-darwin -- switch --flake .#macbook

# For macOS (subsequent updates)
darwin-rebuild switch --flake .#macbook
```

### FlakeHub Direct (no git clone)

```bash
sudo nixos-rebuild switch --flake 'https://flakehub.com/f/coal-bap/nix-devbox/*#devbox'
```

## Container Management

The orchestrator hosts (`devbox`, `devbox-wsl`) include the `devbox-ctl` CLI for managing dev containers:

```bash
# Create a container
devbox-ctl create my-project

# Create with Syncthing file sync
devbox-ctl create my-project --with-syncthing

# List containers
devbox-ctl list

# Container lifecycle
devbox-ctl start my-project
devbox-ctl stop my-project
devbox-ctl destroy my-project

# View status and logs
devbox-ctl status my-project
devbox-ctl logs my-project -f

# Rotate Tailscale auth key
devbox-ctl rotate-key my-project
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
├── podman.nix               # Podman rootless containers
├── docker.nix               # Docker daemon (legacy)
├── users.nix                # User accounts + Home Manager
├── code-server.nix          # Per-user code-server instances
├── ttyd.nix                 # Web terminal sharing
├── syncthing.nix            # File synchronization
├── hyprland.nix             # Wayland compositor (desktop)
├── orchestrator.nix         # Dev container orchestrator
└── orchestrator-cleanup.nix # Idle container cleanup timer

darwin/                      # nix-darwin modules (macOS)
├── core.nix                 # Nix settings, macOS defaults, security
└── aerospace.nix            # Aerospace tiling window manager

containers/                  # OCI container images (dockertools)
└── devcontainer/            # Dev container with CLI, Tailscale, code-server

home/                        # Home Manager configuration (shared across platforms)
├── modules/                 # Reusable building blocks
│   ├── cli.nix              # Core CLI tools (bat, eza, fzf, yazi, etc.)
│   ├── fish.nix             # Fish shell config
│   ├── git.nix              # Git + lazygit + gh
│   ├── dev.nix              # Dev tools (neovim, zellij, AI tools, Rust)
│   └── remote-access.nix    # code-server + Zed remote config
├── profiles/                # Composable bundles
│   ├── minimal.nix          # cli + fish + git
│   ├── developer.nix        # minimal + dev tools
│   ├── workstation.nix      # developer (for local machines)
│   └── container.nix        # developer + remote-access (for containers)
└── users/                   # Per-user configs
    ├── coal.nix             # Admin user
    └── violino.nix          # Dev user

lib/                         # Shared libraries
├── users.nix                # User metadata (SSH keys, UIDs, etc.)
├── containers.nix           # Container config schema
├── schema.nix               # Configuration validation
└── mkHost.nix               # Host configuration helper

scripts/                     # CLI tools
└── devbox-ctl/              # Container management CLI

hosts/                       # Machine-specific configurations
├── devbox/                  # Bare-metal/VM (orchestrator)
├── devbox-wsl/              # WSL2 (orchestrator)
├── devbox-desktop/          # Headful desktop (Hyprland)
└── macbook/                 # macOS workstation
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

## Service Access

### code-server (Browser-based VS Code)

| User | Port | Access URL |
|------|------|------------|
| coal (admin) | 8080 | `http://devbox:8080` |
| violino (dev) | 8081 | `http://devbox:8081` |

### Dev Containers

| Service | Port | Access |
|---------|------|--------|
| SSH | Tailscale | `ssh dev@container-name` |
| code-server | 8080 | `http://container-name:8080` |
| Syncthing GUI | 8384 | `http://container-name:8384` |

## Platform Support

| Platform | Status | Directory | Host |
|----------|--------|-----------|------|
| NixOS (bare-metal) | ✅ Implemented | `nixos/` | `hosts/devbox/` |
| NixOS (WSL) | ✅ Implemented | `nixos/` | `hosts/devbox-wsl/` |
| NixOS (desktop) | ✅ Implemented | `nixos/` | `hosts/devbox-desktop/` |
| macOS (nix-darwin) | ✅ Implemented | `darwin/` | `hosts/macbook/` |
| Containers | ✅ Implemented | `containers/` | N/A |

## Resources

- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Home Manager](https://github.com/nix-community/home-manager)
- [nix-darwin](https://github.com/nix-darwin/nix-darwin)
- [FlakeHub](https://flakehub.com/flake/coal-bap/nix-devbox)