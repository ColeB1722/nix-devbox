# nix-devbox Development Guidelines

Multi-platform Nix configuration for development machines. Supports NixOS (bare-metal, WSL), with planned support for macOS (nix-darwin) and containers (dockertools).

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
└── hyprland.nix             # Wayland compositor (opt-in, headed only)

darwin/                      # nix-darwin modules (planned)
└── README.md                # Implementation notes

# ─── Shared User Config (Home Manager) ─────────────────────
home/
├── modules/                 # Reusable HM building blocks
│   ├── cli.nix              # Core CLI tools (bat, eza, fzf, yazi, etc.)
│   ├── fish.nix             # Fish shell config (aliases, abbrs)
│   ├── git.nix              # Git + lazygit + gh
│   └── dev.nix              # Dev tools (neovim, zellij, AI tools, Rust)
├── profiles/                # Composable bundles
│   ├── minimal.nix          # cli + fish + git
│   └── developer.nix        # minimal + dev tools
└── users/                   # Per-user configs
    ├── coal.nix             # Admin user (imports developer profile)
    └── violino.nix          # Dev user (imports developer profile)

# ─── Container Builds ──────────────────────────────────────
containers/                  # dockertools image definitions (planned)
└── README.md                # Implementation notes

# ─── Shared Data ───────────────────────────────────────────
lib/
└── users.nix                # User metadata (names, UIDs, SSH keys)

# ─── Host Configurations ───────────────────────────────────
hosts/
├── devbox/                  # NixOS bare-metal/VM
│   ├── default.nix
│   └── hardware-configuration.nix.example
└── devbox-wsl/              # NixOS on WSL2
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

## WSL Deployment

For deploying to Windows Subsystem for Linux:

```bash
# Inside WSL after cloning the repo
sudo nixos-rebuild switch --flake .#devbox-wsl
```

Key differences from bare-metal:
- No hardware-configuration.nix needed
- Tailscale runs inside WSL (uses wireguard-go)
- Custom firewall config (allows SSH on port 22)
- No Docker/Podman module (uses Docker Desktop on Windows host)
- No Hyprland (no display support in WSL)

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

3. Add to `nixos/users.nix` (NixOS) or `darwin/users.nix` (macOS).

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

## Platform Support Status

| Platform | Status | Directory |
|----------|--------|-----------|
| NixOS (bare-metal) | ✅ Implemented | `nixos/`, `hosts/devbox/` |
| NixOS (WSL) | ✅ Implemented | `nixos/`, `hosts/devbox-wsl/` |
| macOS (nix-darwin) | 🚧 Planned | `darwin/` |
| Containers (dockertools) | 🚧 Planned | `containers/` |

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

### Home Manager Modules (`home/modules/`)

| Module | Purpose |
|--------|---------|
| `cli.nix` | Core CLI tools (ripgrep, fd, bat, eza, fzf, yazi, direnv) |
| `fish.nix` | Fish shell config (aliases, abbreviations) |
| `git.nix` | Git config + lazygit + GitHub CLI |
| `dev.nix` | Dev tools (neovim, zellij, tmux, AI tools, Rust, runtimes) |

### Home Manager Profiles (`home/profiles/`)

| Profile | Includes |
|---------|----------|
| `minimal.nix` | cli + fish + git |
| `developer.nix` | minimal + dev |

## Active Technologies
- Nix (flakes), NixOS 25.05 + nixpkgs, home-manager, nixos-wsl, FlakeHub (007-library-flake-architecture)
- N/A (configuration-only, no runtime storage) (007-library-flake-architecture)
- Nix (flakes), NixOS 25.05 + nixpkgs, home-manager, nixos-wsl, (future: nix-darwin) (008-extended-devtools)

## Recent Changes
- 008-extended-devtools: Added goose-cli, Rust toolchain, yazi, Podman, ttyd, Syncthing, Hyprland modules
- 007-library-flake-architecture: Added Nix (flakes), NixOS 25.05 + nixpkgs, home-manager, nixos-wsl, FlakeHub
