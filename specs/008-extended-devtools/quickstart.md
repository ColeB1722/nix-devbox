# Quickstart: Extended Development Tools

**Feature**: 008-extended-devtools  
**Date**: 2026-01-25

## Overview

This guide covers how to use the new development tools added in feature 008.

---

## CLI Tools (All Platforms)

### yazi - Terminal File Manager

Navigate files with keyboard-driven interface:

```bash
# Open yazi in current directory
yazi

# Open in specific directory
yazi ~/projects
```

**Key bindings**:
- `j/k` - Move down/up
- `l` - Enter directory / open file
- `h` - Go to parent directory
- `q` - Quit
- `y` - Yank (copy)
- `p` - Paste
- `d` - Delete
- `r` - Rename
- `/` - Search

### goose - AI Agent CLI

Block's open-source AI agent for terminal:

```bash
# Start interactive session
goose

# Run with specific provider (requires API key)
OPENAI_API_KEY=<key> goose

# Or use 1Password for secrets
OPENAI_API_KEY=$(op read "op://Development/OpenAI/api-key") goose
```

**Note**: Goose requires an API key for the LLM provider. Configure via environment variable or 1Password.

### Rust Toolchain

Rust development tools are now available:

```bash
# Check versions
rustc --version
cargo --version

# Create new project
cargo new my-project
cd my-project

# Build and run
cargo build
cargo run

# Format code
cargo fmt

# Lint code
cargo clippy
```

---

## Container Runtime (Bare-metal NixOS Only)

### Podman

Rootless container runtime (Docker alternative):

```bash
# Verify installation
podman --version

# Run hello-world
podman run hello-world

# Pull an image
podman pull alpine

# Run interactive container
podman run -it alpine sh

# List containers
podman ps -a

# Build from Dockerfile (yes, Dockerfile!)
podman build -t myimage .
```

**Docker Compatibility**: The `docker` command is aliased to `podman`:

```bash
# These work the same
docker run hello-world
podman run hello-world
```

**WSL Note**: WSL configurations use Docker Desktop on Windows host. Podman is not installed on WSL.

---

## Terminal Sharing (NixOS)

### ttyd - Web Terminal

Share your terminal via web browser (accessible only via Tailscale):

```bash
# Start terminal sharing on port 7681
ttyd fish

# Specify different port
ttyd -p 8080 fish

# With authentication (recommended for persistent sessions)
ttyd -c user:password fish

# Read-only mode (viewers can't type)
ttyd -R fish
```

**Access**: Navigate to `http://<hostname>:7681` from any machine on your tailnet.

**Security**: ttyd port is only accessible via Tailscale interface. Not exposed to public internet.

---

## File Synchronization (NixOS)

### Syncthing

Continuous file sync between machines:

**Web GUI Access**:
```
http://<hostname>:8384
```

Access from any machine on your tailnet.

**Initial Setup**:
1. Open Web GUI on each machine
2. Add devices (use Device ID from Actions → Show ID)
3. Create shared folders
4. Accept folder/device on other machines

**Default Sync Folder**: `~/Sync`

**CLI Status**:
```bash
# Check service status
systemctl status syncthing

# View logs
journalctl -u syncthing -f
```

---

## Platform-Specific Tools

### Aerospace (macOS - Future)

**Status**: Available after nix-darwin implementation.

Tiling window manager for macOS:

```bash
# Start Aerospace
aerospace

# Config location
~/.config/aerospace/aerospace.toml
```

### Hyprland (Headed NixOS - Future)

**Status**: Opt-in module for headed NixOS installations.

Wayland compositor with tiling support:

```bash
# Enable in host configuration
devbox.hyprland.enable = true;

# After rebuild, select Hyprland session at login
```

**Note**: Not applicable to headless servers or WSL.

---

## Module Configuration

### Enable/Disable in Host Configuration

Edit your host's `default.nix`:

```nix
# For Podman (bare-metal only)
devbox.podman.enable = true;  # default: true when module imported

# For ttyd
devbox.ttyd.enable = true;    # default: false

# For Syncthing  
devbox.syncthing.enable = true;  # default: false
devbox.syncthing.user = "coal";  # default: first admin

# For Hyprland (headed only)
devbox.hyprland.enable = true;   # default: false
```

### Rebuild

```bash
# Build without deploying (test)
nixos-rebuild build --flake .#devbox

# Deploy
sudo nixos-rebuild switch --flake .#devbox

# Or use just
just build
just deploy
```

---

## Troubleshooting

### Podman: Permission Denied

If you get permission errors with rootless Podman:

```bash
# Verify subuid/subgid are configured
cat /etc/subuid
cat /etc/subgid

# Should show entries like:
# coal:100000:65536
```

If missing, rebuild NixOS configuration.

### ttyd: Connection Refused

1. Verify ttyd is running: `pgrep ttyd`
2. Check firewall: Port should be open on tailscale0 interface
3. Verify you're accessing via Tailscale network

### Syncthing: Devices Not Discovering

1. Ensure both machines are on the same tailnet
2. Check firewall ports (22000 TCP/UDP, 21027 UDP on tailscale0)
3. Try manual device addition via Device ID

### goose: API Key Error

```bash
# Check if API key is set
echo $OPENAI_API_KEY

# Set via 1Password
export OPENAI_API_KEY=$(op read "op://Development/OpenAI/api-key")
```

---

## Quick Reference

| Tool | Command | Purpose |
|------|---------|---------|
| yazi | `yazi` | File manager |
| goose | `goose` | AI agent |
| cargo | `cargo build` | Rust build |
| podman | `podman run` | Containers |
| ttyd | `ttyd fish` | Terminal sharing |
| syncthing | Web GUI :8384 | File sync |