# nix-devbox Development Guidelines

Multi-platform Nix configuration for development machines. Supports NixOS (bare-metal, WSL, headful desktop), macOS (nix-darwin), and containers (dockertools).

## Architecture Overview

```
flake.nix                    # Entry point with inputs/outputs

# ─── Platform-Specific System Config ───────────────────────
nixos/                       # NixOS modules (flat structure)
├── core.nix                 # Locale, timezone, nix settings
├── ssh.nix                  # SSH hardening
├── firewall.nix             # iptables/nftables rules
├── tailscale.nix            # Tailscale VPN service
├── podman.nix               # Podman rootless containers (bare-metal)
├── docker.nix               # Docker daemon (legacy, replaced by podman)
├── fish.nix                 # Fish shell (system-level)
├── users.nix                # User accounts + Home Manager integration
├── code-server.nix          # Per-user code-server instances
├── ttyd.nix                 # Web terminal sharing (Tailscale-only)
├── syncthing.nix            # File synchronization (Tailscale-only)
├── hyprland.nix             # Wayland compositor (opt-in, headed only)
├── orchestrator.nix         # Dev container orchestrator
└── orchestrator-cleanup.nix # Idle container cleanup timer

darwin/                      # nix-darwin modules (macOS)
├── core.nix                 # Nix settings, system defaults, security
└── aerospace.nix            # Tiling window manager (like i3)

containers/                  # OCI container images (dockertools)
├── README.md                # Container build and usage
└── devcontainer/            # Dev container image
    └── default.nix          # Layered image with CLI, Tailscale, code-server

# ─── Shared User Config (Home Manager) ─────────────────────
home/
├── modules/                 # Reusable HM building blocks
│   ├── cli.nix              # Core CLI tools (bat, eza, fzf, yazi, etc.)
│   ├── fish.nix             # Fish shell config (aliases, abbrs)
│   ├── git.nix              # Git + lazygit + gh
│   ├── dev.nix              # Dev tools (neovim, zellij, AI tools, Rust)
│   └── remote-access.nix    # code-server + Zed remote config
├── profiles/                # Composable bundles
│   ├── minimal.nix          # cli + fish + git
│   ├── developer.nix        # minimal + dev tools
│   ├── workstation.nix      # developer (for local machines)
│   └── container.nix        # developer + remote-access (for containers)
└── users/                   # Per-user configs
    ├── coal.nix             # Admin user (imports developer profile)
    └── violino.nix          # Dev user (imports developer profile)

# ─── CLI Tools ─────────────────────────────────────────────
scripts/
└── devbox-ctl/              # Container management CLI
    ├── devbox_ctl.py        # Python CLI (click framework)
    └── package.nix          # Nix package definition

# ─── Shared Data ───────────────────────────────────────────
lib/
├── users.nix                # User metadata (names, UIDs, SSH keys)
├── schema.nix               # Configuration validation
├── containers.nix           # Container config schema
└── mkHost.nix               # Host configuration helper

# ─── Host Configurations ───────────────────────────────────
hosts/
├── devbox/                  # NixOS bare-metal/VM (orchestrator)
│   ├── default.nix
│   └── hardware-configuration.nix.example
├── devbox-wsl/              # NixOS on WSL2 (orchestrator)
│   └── default.nix
├── devbox-desktop/          # NixOS headful workstation (Hyprland)
│   ├── default.nix
│   └── hardware-configuration.nix.example
└── macbook/                 # macOS workstation (nix-darwin)
    └── default.nix

# ─── Project Config ────────────────────────────────────────
specs/                       # Feature specifications (speckit)
docs/                        # Additional documentation
.github/workflows/           # CI/CD
```

## Key Design Principles

1. **Platform separation**: NixOS and Darwin modules are fundamentally incompatible. Each gets its own directory (`nixos/`, `darwin/`).

2. **Home Manager is the shared layer**: User-level config in `home/` works across all platforms. This is where the "shared core" CLI tools live.

3. **Flat modules within platforms**: No nested directories. `nixos/tailscale.nix` not `modules/networking/tailscale.nix`.

4. **Profiles for composition**: Users import profiles (e.g., `developer.nix`) which compose modules.

5. **Centralized user data**: SSH keys, UIDs, and user metadata live in `lib/users.nix` and are consumed by platform-specific modules.

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

## Deployment Commands by Platform

### NixOS (bare-metal / VM)
```bash
sudo nixos-rebuild switch --flake .#devbox
```

### NixOS (WSL2)
```bash
sudo nixos-rebuild switch --flake .#devbox-wsl
```

### NixOS (Headful Desktop with Hyprland)
```bash
sudo nixos-rebuild switch --flake .#devbox-desktop
```

### macOS (nix-darwin)
```bash
# First time (bootstrap nix-darwin)
nix run nix-darwin -- switch --flake .#macbook

# Subsequent updates
darwin-rebuild switch --flake .#macbook
```

## Container Management (devbox-ctl)

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
```

## Adding a New User

1. Add user data to `lib/users.nix`:
   ```nix
   newuser = {
     name = "newuser";
     uid = 1002;
     description = "New User";
     email = "newuser@example.com";
     gitUser = "newuser";
     isAdmin = false;
     sshKeys = [ "ssh-ed25519 AAAA..." ];
     extraGroups = [];
   };
   ```

2. Create Home Manager config at `home/users/newuser.nix`:
   ```nix
   { ... }:
   let users = import ../../lib/users.nix; in {
     imports = [ ../profiles/developer.nix ];
     home.username = users.newuser.name;
     home.homeDirectory = "/home/${users.newuser.name}";
     programs.git.userName = users.newuser.gitUser;
     programs.git.userEmail = users.newuser.email;
   }
   ```

3. Add to `nixos/users.nix` (NixOS) or create darwin user config (macOS).

## Code Style

- **Nix files**: 2-space indentation, inline comments for non-obvious decisions
- **Module pattern**: Use `lib.mkDefault` for overridable defaults
- **Flat structure**: One module per file, descriptive filenames

## Security

### Pre-commit Security Hooks

The following security checks run on every commit:
- **gitleaks**: Scans for secrets, API keys, and credentials
- **detect-private-key**: Blocks commits containing private keys

### NixOS Assertions

Security properties enforced via NixOS assertions:
- Firewall MUST be enabled (`nixos/firewall.nix`)
- SSH password authentication MUST be disabled (`nixos/ssh.nix`)
- SSH root login MUST be denied (`nixos/ssh.nix`)
- Non-admin users MUST NOT be in wheel group (`nixos/users.nix`)
- Orchestrator requires firewall + hardened SSH (`nixos/orchestrator.nix`)

### Public Repository Safety

This repo is designed to be safely public:
- No secrets or credentials committed
- SSH public keys only (private keys never committed)
- Pre-commit hooks prevent accidental secret commits
- Hardware-specific configs are gitignored

## Service Access

### code-server (Browser-based VS Code)

Access is controlled by Tailscale ACLs.

| User | Port | Access URL |
|------|------|------------|
| coal (admin) | 8080 | `http://devbox:8080` |
| violino (dev) | 8081 | `http://devbox:8081` |

Port assignments are defined in `lib/users.nix` under `codeServerPorts`.

### Dev Containers

| Service | Port | Access |
|---------|------|--------|
| SSH | Tailscale | `ssh dev@container-name` |
| code-server | 8080 | `http://container-name:8080` |
| Syncthing GUI | 8384 | `http://container-name:8384` |
| Syncthing Sync | 22000 | Internal |

## Platform Support Status

| Platform | Status | Directory | Host |
|----------|--------|-----------|------|
| NixOS (bare-metal) | ✅ Implemented | `nixos/` | `hosts/devbox/` |
| NixOS (WSL) | ✅ Implemented | `nixos/` | `hosts/devbox-wsl/` |
| NixOS (headful desktop) | ✅ Implemented | `nixos/` | `hosts/devbox-desktop/` |
| macOS (nix-darwin) | ✅ Implemented | `darwin/` | `hosts/macbook/` |
| Containers (dockertools) | ✅ Implemented | `containers/` | N/A |

## Module Reference

### NixOS Modules (`nixos/`)

| Module | Purpose |
|--------|---------|
| `core.nix` | Nix flakes, locale, timezone, bootloader |
| `firewall.nix` | Default-deny firewall, Tailscale trust |
| `tailscale.nix` | Tailscale VPN service |
| `ssh.nix` | Hardened SSH (key-only, no root) |
| `fish.nix` | Fish shell system enablement |
| `podman.nix` | Podman rootless containers (bare-metal only) |
| `docker.nix` | Docker daemon + auto-prune (legacy) |
| `users.nix` | User accounts + Home Manager |
| `code-server.nix` | Per-user VS Code in browser |
| `ttyd.nix` | Web terminal sharing (Tailscale-only) |
| `syncthing.nix` | File synchronization service (Tailscale-only) |
| `hyprland.nix` | Wayland compositor (opt-in, headed systems) |
| `orchestrator.nix` | Dev container orchestrator (Podman, devbox-ctl) |
| `orchestrator-cleanup.nix` | Timer for idle container cleanup |

### Darwin Modules (`darwin/`)

| Module | Purpose |
|--------|---------|
| `core.nix` | Nix settings, macOS defaults, security (Touch ID sudo) |
| `aerospace.nix` | Aerospace tiling window manager |

### Home Manager Modules (`home/modules/`)

| Module | Purpose |
|--------|---------|
| `cli.nix` | Core CLI tools (ripgrep, fd, bat, eza, fzf, yazi, direnv) |
| `fish.nix` | Fish shell config (aliases, abbreviations) |
| `git.nix` | Git config + lazygit + GitHub CLI |
| `dev.nix` | Dev tools (neovim, zellij, tmux, AI tools, Rust, runtimes) |
| `remote-access.nix` | code-server and Zed remote configuration |

### Home Manager Profiles (`home/profiles/`)

| Profile | Includes | Use Case |
|---------|----------|----------|
| `minimal.nix` | cli + fish + git | Minimal shell environment |
| `developer.nix` | minimal + dev | Full development environment |
| `workstation.nix` | developer | Local machines (macOS, Linux desktop) |
| `container.nix` | developer + remote-access | Dev containers |

## Active Technologies

- **Nix**: Flakes, NixOS 25.05, nixpkgs, home-manager
- **Platforms**: NixOS, nixos-wsl, nix-darwin
- **Containers**: Podman (rootless), dockertools for image builds
- **Networking**: Tailscale (SSH, service mesh)
- **Services**: code-server, Syncthing, ttyd
- **Window Managers**: Hyprland (NixOS), Aerospace (macOS)

## Recent Changes

- 009-devcontainer-orchestrator: Container orchestrator, devbox-ctl CLI, darwin modules, devbox-desktop host
- 008-extended-devtools: Added goose-cli, Rust toolchain, yazi, Podman, ttyd, Syncthing, Hyprland modules
- 007-library-flake-architecture: Library flake structure, FlakeHub publishing