# Research: Multi-Platform Development Environment

**Feature Branch**: `009-devcontainer-orchestrator`  
**Date**: 2025-01-25  
**Status**: Complete

## 1. dockertools Patterns

### Decision: Use `dockertools.buildLayeredImage` for dev container images

### Rationale
- `buildLayeredImage` creates layer-efficient images that share common layers across rebuilds
- Better caching than `buildImage` for iterative development
- Native Nix integration means all packages are pinned to flake inputs
- No Dockerfile required - purely declarative

### Alternatives Considered

| Alternative | Rejected Because |
|-------------|------------------|
| `dockertools.buildImage` | Single layer, poor caching, slow rebuilds |
| External Dockerfile | Breaks declarative principle, requires Docker daemon |
| Distroless base + Nix overlay | Unnecessary complexity, Nix handles minimality |

### Implementation Notes

```nix
pkgs.dockerTools.buildLayeredImage {
  name = "devcontainer";
  tag = "latest";
  contents = [
    # CLI tools from home-manager profile
    pkgs.bashInteractive
    pkgs.coreutils
    # ... other packages
  ];
  config = {
    Cmd = [ "/bin/bash" ];
    Env = [ "PATH=/bin" ];
  };
}
```

Key considerations:
- Use `contents` for packages, not `copyToRoot` (deprecated)
- Set `maxLayers = 100` to allow fine-grained caching
- Include `/etc/passwd` and `/etc/group` for proper user handling

---

## 2. Tailscale in Containers

### Decision: Run Tailscale in userspace networking mode inside rootless Podman containers

### Rationale
- Rootless Podman cannot create TUN devices without host configuration
- Userspace networking (`--userspace-networking`) works without elevated privileges
- Auth key passed via environment variable at container start (not baked into image)
- Tailscale SSH enabled via `--ssh` flag on `tailscale up`

### Alternatives Considered

| Alternative | Rejected Because |
|-------------|------------------|
| Host TUN passthrough | Requires root, breaks rootless container principle |
| Tailscale on host only | Containers wouldn't have individual Tailscale identities |
| WireGuard direct | More complex, loses Tailscale ACL/SSH benefits |

### Implementation Notes

Container entrypoint script:
```bash
#!/bin/bash
tailscaled --tun=userspace-networking &
sleep 2
tailscale up --authkey="${TS_AUTHKEY}" --ssh --hostname="${CONTAINER_NAME}"
exec "$@"
```

Environment variables passed at runtime:
- `TS_AUTHKEY` - Retrieved from 1Password, never logged
- `CONTAINER_NAME` - User-chosen container name for Tailscale hostname

Podman run flags:
- `--cap-add=NET_ADMIN` - Required for userspace networking
- `--device=/dev/net/tun` - Not needed with userspace mode

---

## 3. nix-darwin Setup

### Decision: Use flake-based nix-darwin with home-manager as module

### Rationale
- Flake-based matches existing NixOS pattern
- home-manager as nix-darwin module (not standalone) for unified configuration
- Shared CLI modules between darwin and NixOS via home-manager

### Alternatives Considered

| Alternative | Rejected Because |
|-------------|------------------|
| Standalone home-manager on macOS | Doesn't manage system-level settings (keyboard, defaults) |
| Homebrew for GUI apps | Breaks declarative principle |
| nix-darwin without flakes | Inconsistent with existing NixOS flake setup |

### Implementation Notes

Flake structure addition:
```nix
{
  outputs = { self, nixpkgs, darwin, home-manager, ... }: {
    darwinConfigurations.macbook = darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      modules = [
        ./darwin/core.nix
        ./darwin/aerospace.nix
        home-manager.darwinModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.coal = import ./home/users/coal.nix;
        }
      ];
    };
  };
}
```

Key darwin-specific considerations:
- Use `system.defaults` for macOS preferences
- Use `homebrew.casks` only for apps not in nixpkgs (last resort)
- Nix-darwin manages launchd services, not systemd

---

## 4. Aerospace Configuration

### Decision: Configure Aerospace via nix-darwin `home-manager` with TOML config file

### Rationale
- Aerospace uses TOML configuration at `~/.aerospace.toml`
- home-manager can manage this file declaratively
- Aerospace available in nixpkgs as `aerospace`

### Alternatives Considered

| Alternative | Rejected Because |
|-------------|------------------|
| yabai + skhd | Requires SIP disable, more complex |
| Amethyst | Less configurable, no workspaces |
| Rectangle | Not a true tiling WM |

### Implementation Notes

home-manager config:
```nix
{
  home.packages = [ pkgs.aerospace ];
  
  xdg.configFile."aerospace/aerospace.toml".text = ''
    start-at-login = true
    
    [gaps]
    inner.horizontal = 10
    inner.vertical = 10
    outer.left = 10
    outer.right = 10
    outer.top = 10
    outer.bottom = 10
    
    [mode.main.binding]
    alt-h = "focus left"
    alt-j = "focus down"
    alt-k = "focus up"
    alt-l = "focus right"
    alt-shift-h = "move left"
    alt-shift-j = "move down"
    alt-shift-k = "move up"
    alt-shift-l = "move right"
    # ... workspace bindings
  '';
}
```

---

## 5. 1Password CLI Integration

### Decision: Use single global Service Account with `op read`, not per-user logins

### Rationale
- Service Account = system-wide credential, not tied to any individual user
- Authenticates via `OP_SERVICE_ACCOUNT_TOKEN` environment variable
- Can read from specific vaults granted access (e.g., `DevBox`)
- Perfect for server/orchestrator scenarios - no interactive login needed
- `op read "op://vault/item/field"` retrieves secrets on-demand

### Alternatives Considered

| Alternative | Rejected Because |
|-------------|------------------|
| Per-user 1Password logins | Requires interactive auth, complex multi-user setup |
| HashiCorp Vault | Additional infrastructure to manage |
| Environment variables in config | Secrets would be in Nix store (world-readable) |
| agenix/sops-nix | Requires encryption keys on host, complex for per-user secrets |

### Implementation Notes

**Service Account Setup (done by consumer):**
1. Create Service Account in 1Password web console
2. Grant read access to the vault (e.g., `DevBox`)
3. Store token securely on orchestrator

**Orchestrator Configuration:**
```bash
# Service account token set in systemd unit (NOT in Nix config)
# Options: systemd credential, agenix, /run/secrets, etc.
Environment="OP_SERVICE_ACCOUNT_TOKEN=ops_xxxxx..."
```

**Secret Retrieval (in devbox-ctl):**
```bash
# Get vault name from users.nix containers config
VAULT="${CONTAINERS_OP_VAULT:-DevBox}"

# Derive item name from username (convention: {username}-tailscale-authkey)
ITEM="${USERNAME}-tailscale-authkey"

# Retrieve auth key (never log output!)
TS_AUTHKEY=$(op read "op://${VAULT}/${ITEM}/password")

# Pass to container
podman run --env TS_AUTHKEY="$TS_AUTHKEY" ...
```

**1Password Vault Structure (consumer creates):**
```
DevBox/                              # Vault name (configurable in users.nix)
├── coal-tailscale-authkey           # Item per user
│   └── password: tskey-auth-xxx...  # Field containing Tailscale auth key
├── violino-tailscale-authkey
│   └── password: tskey-auth-yyy...
└── ...
```

**Naming Conventions:**
| Component | Convention | Example |
|-----------|------------|---------|
| Vault | Consumer-configurable | `DevBox` |
| Item name | `{username}-tailscale-authkey` | `coal-tailscale-authkey` |
| Field | `password` | `tskey-auth-xxxx...` |
| Reference | `op://{vault}/{username}-tailscale-authkey/password` | `op://DevBox/coal-tailscale-authkey/password` |

**Security Considerations:**
- Service account token stored via systemd credential or `/run/secrets` (never in Nix store)
- Never echo, log, or store auth keys to files
- Token grants read-only access to specific vault only
- Rate limits apply: 1000 reads/hour for Teams, 10000 for Business

---

## 6. Podman Systemd Integration

### Decision: Use Podman Quadlet for systemd-native container management

### Rationale
- Quadlet generates systemd units from container definitions
- Native support for auto-restart, dependencies, resource limits
- Works with rootless Podman
- Simpler than manual systemd unit files

### Alternatives Considered

| Alternative | Rejected Because |
|-------------|------------------|
| `podman generate systemd` | Deprecated in favor of Quadlet |
| Manual systemd units | More maintenance, error-prone |
| Docker Compose via podman-compose | Extra layer, not native |

### Implementation Notes

Quadlet container file (`~/.config/containers/systemd/devcontainer-mydev.container`):
```ini
[Container]
Image=localhost/devcontainer:latest
ContainerName=mydev
PublishPort=
Environment=TS_AUTHKEY=%d/ts-authkey
Environment=CONTAINER_NAME=mydev
Volume=mydev-data:/home/dev:Z

# Resource limits
CPUQuota=200%
MemoryLimit=4G

[Service]
Restart=always
RestartSec=10

[Install]
WantedBy=default.target
```

Cleanup timer (`devbox-cleanup.timer`):
```ini
[Unit]
Description=Check for idle containers

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
```

NixOS integration:
- Generate Quadlet files via Nix module
- Use `systemd.user.services` for user-scoped containers
- Timer checks container last activity, stops/destroys as needed

---

## 7. Zed Remote Server

### Decision: Include `zed-editor` remote server binary, activated on-demand via SSH

### Rationale
- Zed remote works via SSH connection to `zed --remote-cli`
- No persistent server needed - Zed client initiates connection
- Available in nixpkgs as `zed-editor`

### Alternatives Considered

| Alternative | Rejected Because |
|-------------|------------------|
| VS Code Server (code-server) | Already included, Zed is additional option |
| JetBrains Gateway | Requires JetBrains license, heavier |
| Neovim only | Users want GUI editor option |

### Implementation Notes

Container includes:
```nix
{
  home.packages = [
    pkgs.zed-editor  # Provides `zed` CLI
  ];
}
```

User workflow:
1. Open Zed locally
2. Use "Connect to Server" with SSH path: `user@container.tailnet`
3. Zed establishes SSH connection, runs remote CLI automatically

No additional configuration needed - Zed handles remote server lifecycle.

---

## 8. Syncthing in Containers

### Decision: Optional Syncthing daemon inside containers for bidirectional file sync with local workstations

### Rationale
- Enables offline work on local machine, syncs when container is running
- Runs over Tailscale (encrypted, no port forwarding needed)
- Keeps orchestrator minimal (no Syncthing on host)
- Per-container sync identity allows granular control
- Well-established pattern - Docker acquired Mutagen for similar use case

### Alternatives Considered

| Alternative | Rejected Because |
|-------------|------------------|
| Syncthing on orchestrator host | Violates minimalism principle, complicates host |
| Mutagen | Requires session recreation on container restart, point-to-point only |
| rsync scripts | Manual, no real-time sync, requires scripting |
| Host bind mounts | Security risk, breaks container portability |
| No sync (SSH/Zed only) | Valid default, but users want offline access |

### Implementation Notes

Container layer (`containers/devcontainer/syncthing.nix`):
```nix
{ pkgs, ... }:
{
  # Syncthing daemon
  home.packages = [ pkgs.syncthing ];
  
  # Config persisted in volume
  # ~/.config/syncthing/ is in /home/dev which is the volume mount
  
  # Entrypoint addition (when --with-syncthing flag used):
  # syncthing serve --no-browser --gui-address=0.0.0.0:8384 &
}
```

CLI integration:
```bash
# Create with Syncthing enabled
devbox-ctl create my-project --with-syncthing

# Container exposes ports via Tailscale:
# - 8384: Syncthing GUI (for pairing)
# - 22000: Syncthing sync protocol
```

User pairing workflow:
1. Create container with `--with-syncthing`
2. Open `http://my-project.tailnet:8384` in browser
3. In local Syncthing, add remote device (container's device ID)
4. Accept pairing in container's Syncthing GUI
5. Share `/home/dev/sync` folder bidirectionally
6. Done - files sync automatically

Sync folder location:
- Container: `/home/dev/sync`
- Local Mac: `~/Sync` (or user's choice)

Conflict handling:
- Syncthing's built-in conflict resolution (creates `.sync-conflict` files)
- User resolves manually via Syncthing GUI

Persistence:
- Syncthing config in `/home/dev/.config/syncthing/` (inside volume)
- Device ID and pairings survive container stop/start
- Survives `--keep-volume` on destroy

---

## Summary of Technology Choices

| Component | Technology | Confidence |
|-----------|------------|------------|
| Container images | dockertools.buildLayeredImage | High |
| Container runtime | Podman (rootless) + Quadlet | High |
| Tailscale in containers | Userspace networking mode | Medium-High |
| macOS config | nix-darwin + home-manager | High |
| Tiling (macOS) | Aerospace | High |
| Tiling (Linux) | Hyprland (from 008) | High |
| Secrets | 1Password CLI (`op`) | High |
| Remote IDE | code-server + Zed remote | High |
| File sync | Syncthing (optional, in-container) | High |
| CLI tool | Bash scripts (devbox-ctl) | Medium |

**Medium confidence items**: 
- Tailscale userspace networking may have performance implications - monitor and adjust
- Bash CLI tool may need rewrite to more robust language if complexity grows
- Syncthing pairing UX requires one-time manual setup per container