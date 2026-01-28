# Container Builds (dockerTools)

This directory contains OCI container image definitions using Nix's `dockerTools.buildLayeredImage`.

## Overview

The devcontainer is a fully-configured development environment packaged as an OCI image. It includes:

- Full CLI development toolkit (ripgrep, fd, bat, eza, fzf, jq, git, etc.)
- Development tools (neovim, zellij, nodejs, bun, uv, Rust toolchain)
- Tailscale daemon for secure SSH access via tailnet
- code-server for browser-based VS Code access
- Optional Syncthing for file synchronization

## Directory Structure

```
containers/
├── README.md            # This file
└── devcontainer/
    └── default.nix      # Layered container image definition
```

## Building

```bash
# Build the container image
nix build .#devcontainer

# The result is an OCI image tarball
ls -la result

# Load into Podman
podman load < result

# Or load into Docker
docker load < result

# Verify
podman images | grep devcontainer
```

## Running

### Basic Usage

```bash
# Run interactively
podman run -it --rm devcontainer:latest

# Run with a name
podman run -d --name mydev devcontainer:latest
```

### With Tailscale (Recommended)

For SSH access via your tailnet, provide a Tailscale auth key:

```bash
# Create a secrets directory with your auth key
mkdir -p /tmp/secrets
echo "tskey-auth-xxxxx" > /tmp/secrets/ts_authkey

# Run with Tailscale
podman run -d \
  --name mydev \
  -e CONTAINER_NAME=mydev \
  -v /tmp/secrets:/run/secrets:ro \
  devcontainer:latest
```

Once running, access via:
- **SSH**: `ssh dev@mydev` (via Tailscale)
- **code-server**: `http://mydev:8080`

### With Syncthing

```bash
podman run -d \
  --name mydev \
  -e CONTAINER_NAME=mydev \
  -e SYNCTHING_ENABLED=true \
  -v /tmp/secrets:/run/secrets:ro \
  devcontainer:latest
```

Syncthing GUI available at `http://mydev:8384`

### With Persistent Home Directory

```bash
# Create a volume for persistent data
podman volume create mydev-home

podman run -d \
  --name mydev \
  -e CONTAINER_NAME=mydev \
  -v mydev-home:/home/dev \
  -v /tmp/secrets:/run/secrets:ro \
  devcontainer:latest
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CONTAINER_NAME` | `devcontainer` | Hostname for Tailscale registration |
| `TS_AUTHKEY_FILE` | `/run/secrets/ts_authkey` | Path to Tailscale auth key file |
| `TS_TAGS` | `tag:devcontainer` | Tailscale ACL tags (comma-separated) |
| `SYNCTHING_ENABLED` | `false` | Enable Syncthing file sync service |

## Exposed Ports

| Port | Service |
|------|---------|
| 8080/tcp | code-server (VS Code in browser) |
| 8384/tcp | Syncthing GUI (if enabled) |
| 22000/tcp | Syncthing sync protocol (if enabled) |

## Container User

The container runs as the `dev` user (UID 1000) by default. The home directory is `/home/dev`.

## Tailscale Integration

The container runs Tailscale in userspace networking mode, which works without root privileges or TUN device access. If no auth key is provided, the container will still start but won't be accessible via Tailscale — code-server will bind to localhost only for security.

### Generating an Auth Key

1. Go to [Tailscale Admin Console](https://login.tailscale.com/admin/settings/keys)
2. Generate an auth key with:
   - **Reusable**: Yes (for multiple container starts)
   - **Ephemeral**: Yes (auto-removes from tailnet when container stops)
   - **Tags**: `tag:devcontainer` (or your preferred ACL tags)

## Customization

To add packages to the container image, modify `containers/devcontainer/default.nix` and rebuild.

## How It Works

Unlike NixOS modules, containers don't use a module system at runtime. We use `dockerTools.buildLayeredImage` to create OCI-compliant images with packages baked in at build time:

- **Layer caching**: Shared layers across rebuilds for faster iteration
- **Reproducibility**: Exact package versions pinned via flake inputs
- **Minimality**: Only required packages, no full OS overhead

## Resources

- [dockerTools documentation](https://nixos.org/manual/nixpkgs/stable/#sec-pkgs-dockerTools)
- [Tailscale in containers](https://tailscale.com/kb/1112/userspace-networking)
- [code-server documentation](https://coder.com/docs/code-server/latest)