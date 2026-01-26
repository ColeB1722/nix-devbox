# Container Builds (dockertools)

This directory contains OCI container image definitions using Nix's `dockerTools.buildLayeredImage`.
These containers power the dev container orchestrator feature (009-devcontainer-orchestrator).

## Overview

Dev containers are isolated development environments that run on the orchestrator host.
Each container includes:

- Full CLI development toolkit (shared with NixOS and macOS configurations)
- Tailscale daemon for secure SSH access via tailnet
- code-server for browser-based VS Code access
- Zed remote server for Zed editor integration
- Optional Syncthing for file synchronization with local workstations

## Directory Structure

```
containers/
├── README.md            # This file
└── devcontainer/
    └── default.nix      # Layered container image with all services
```

All services (Tailscale, code-server, Zed remote, Syncthing) and the entrypoint
script are defined within the monolithic `default.nix` file for simplicity.
The image uses `dockerTools.buildLayeredImage` with separate package layers
for caching efficiency.

## How It Works

Unlike NixOS modules, containers don't use a module system at runtime.
We use `dockerTools.buildLayeredImage` to create OCI-compliant images
with packages baked in at build time. This approach provides:

- **Layer caching**: Shared layers across rebuilds for faster iteration
- **Reproducibility**: Exact package versions pinned via flake inputs
- **Minimality**: Only required packages, no full OS overhead

### Container Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Dev Container                               │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │  Tailscale  │  │ code-server │  │ Zed Remote  │  (Optional) │
│  │  (SSH)      │  │ (Browser)   │  │ (Editor)    │  Syncthing  │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
├─────────────────────────────────────────────────────────────────┤
│                     CLI Development Tools                       │
│  ripgrep, fd, bat, eza, fzf, jq, git, gh, neovim, zellij, etc. │
├─────────────────────────────────────────────────────────────────┤
│                     Base Layer (coreutils, bash, etc.)          │
└─────────────────────────────────────────────────────────────────┘
```

## Building

```bash
# Build the dev container image
nix build .#packages.x86_64-linux.devcontainer

# The result is an OCI image tarball
ls -la result

# Load into Podman (on orchestrator)
podman load < result

# Verify
podman images | grep devcontainer
```

## Container Creation Flow

Containers are created via the `devbox-ctl` CLI tool:

```bash
# On the orchestrator, as a user
devbox-ctl create my-project

# What happens:
# 1. Validate name (alphanumeric + hyphens, 3-63 chars)
# 2. Check user's container limit (default: 5)
# 3. Check global container limit (default: 7)
# 4. Retrieve Tailscale auth key from 1Password
# 5. Create Podman volume for persistent data
# 6. Generate Quadlet container definition
# 7. Start container via systemd
# 8. Wait for Tailscale to connect
# 9. Display connection instructions
```

## Accessing Containers

Once created, containers are accessible via:

| Method | Command/URL | Notes |
|--------|-------------|-------|
| SSH | `ssh dev@container-name` | Via Tailscale, key-based auth |
| code-server | `http://container-name:8080` | Browser-based VS Code |
| Zed | Connect to Server → `dev@container-name` | Native Zed app |

All access is authenticated via Tailscale identity - no passwords needed.

## Tailscale Integration

Containers run Tailscale in userspace networking mode, which works without
root privileges or TUN device access:

```bash
# Inside the container at startup (entrypoint.sh):
tailscaled --tun=userspace-networking &
tailscale up --authkey="${TS_AUTHKEY}" --ssh --hostname="${CONTAINER_NAME}"
```

### Tailscale Tags

Each container receives two tags for ACL management:

- `tag:devcontainer` - Common tag for all dev containers
- `tag:{username}-container` - User-specific tag for isolation

Example ACL rules (configured in consumer's homelab-iac):

```json
{
  "acls": [
    {"action": "accept", "src": ["coal@github"], "dst": ["tag:coal-container:*"]},
    {"action": "accept", "src": ["tag:devcontainer"], "dst": ["*:443", "*:80"]}
  ]
}
```

## Persistent Storage

Container data persists in Podman volumes:

| Path | Purpose |
|------|---------|
| `/home/dev` | User home directory (volume: `{container-name}-data`) |
| `/home/dev/.config` | Tool configurations |
| `/home/dev/sync` | Syncthing sync folder (if enabled) |

Volumes survive container stop/start cycles and can be preserved during destroy.

## Optional Syncthing Layer

For bidirectional file sync with local workstations:

```bash
# Create container with Syncthing enabled
devbox-ctl create my-project --with-syncthing

# Access Syncthing GUI to pair devices
# http://my-project:8384 (via Tailscale)
```

Syncthing ports are bound to the Tailscale interface only - not exposed publicly.

## Resource Limits

Default limits (configurable in `users.nix`):

| Resource | Default | Notes |
|----------|---------|-------|
| CPU | 2 cores | Per container |
| Memory | 4G | Per container |
| Containers per user | 5 | Soft limit |
| Containers global | 7 | Based on host resources |

## Lifecycle Automation

Containers are automatically managed to prevent resource waste:

- **Idle stop**: After 7 days of no activity (configurable)
- **Auto-destroy**: After 14 days in stopped state (configurable)

The cleanup timer runs daily via `nixos/orchestrator-cleanup.nix`.

## Sharing Code with Home Manager

The CLI tools installed in containers come from the same Home Manager modules
used for NixOS and macOS configurations:

- `home/modules/cli.nix` - Core CLI tools
- `home/modules/dev.nix` - Development tools
- `home/modules/git.nix` - Git configuration

This ensures tooling consistency across all platforms.

## Customization

### Consumer Overrides

Consumers can customize container behavior via `users.nix`:

```nix
{
  containers = {
    opVault = "MyVault";        # 1Password vault name
    maxPerUser = 3;             # Reduce container limit
    maxGlobal = 10;             # Increase if host has more resources
    defaultCpu = 4;             # More CPU per container
    defaultMemory = "8G";       # More RAM per container
    idleStopDays = 14;          # Longer idle timeout
    stoppedDestroyDays = 30;    # Longer destroy timeout
  };
}
```

### Adding Packages

To add packages to the container image, modify `containers/devcontainer/default.nix`.
Remember to rebuild and reload the image on the orchestrator.

## Troubleshooting

### Container won't start

```bash
# Check container logs
podman logs <container-name>

# Check systemd status (Quadlet-managed)
systemctl --user status container-<container-name>
```

### Tailscale not connecting

```bash
# Inside container
tailscale status

# Check auth key validity
# (done during container creation, key is not stored)
```

### code-server not accessible

```bash
# Check if running
podman exec <container-name> pgrep -f code-server

# Check port binding
podman exec <container-name> ss -tlnp | grep 8080
```

## Resources

- [dockerTools documentation](https://nixos.org/manual/nixpkgs/stable/#sec-pkgs-dockerTools)
- [Tailscale in containers](https://tailscale.com/kb/1112/userspace-networking)
- [Podman Quadlet](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html)
- [code-server documentation](https://coder.com/docs/code-server/latest)