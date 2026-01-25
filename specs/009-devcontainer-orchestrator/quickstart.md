# Quickstart Guide: Multi-Platform Development Environment

**Feature Branch**: `009-devcontainer-orchestrator`  
**Date**: 2025-01-25  
**Status**: Complete

## Overview

This guide covers deployment and usage for all four host configurations:

1. [Orchestrator Host (NixOS)](#1-orchestrator-host-nixos)
2. [Dev Containers](#2-dev-containers)
3. [macOS Workstation (nix-darwin)](#3-macos-workstation-nix-darwin)
4. [Headful NixOS Desktop](#4-headful-nixos-desktop)

## Prerequisites

### All Platforms

- Tailscale account with admin access to generate auth keys
- 1Password account with CLI access (for orchestrator)
- SSH key pair for orchestrator access

### Platform-Specific

| Platform | Requirements |
|----------|--------------|
| Orchestrator (bare-metal) | NixOS 25.05 installed, 32GB+ RAM recommended |
| Orchestrator (WSL2) | Windows 11 with WSL2 + systemd enabled |
| macOS Workstation | macOS 13+, Nix installed (Determinate installer) |
| Headful NixOS | Bare-metal with compatible GPU (AMD/Intel preferred) |

---

## 1. Orchestrator Host (NixOS)

The orchestrator manages dev containers and provides SSH access for container operations.

### 1.1 Bare-Metal Deployment

```bash
# Clone the repository
git clone https://github.com/yourusername/nix-devbox.git
cd nix-devbox

# Copy hardware configuration (first time only)
cp /etc/nixos/hardware-configuration.nix hosts/devbox/

# Deploy
sudo nixos-rebuild switch --flake .#devbox
```

### 1.2 WSL2 Deployment

```powershell
# Enable WSL2 with systemd (PowerShell as Admin)
wsl --install -d NixOS
wsl --set-default NixOS

# Inside WSL
cd /mnt/c/Users/YourName/repos
git clone https://github.com/yourusername/nix-devbox.git
cd nix-devbox

sudo nixos-rebuild switch --flake .#devbox-wsl
```

### 1.3 1Password Setup

```bash
# Install and authenticate 1Password CLI (done via Nix config)
op signin

# Create service account for non-interactive use
# In 1Password web: Settings → Developer → Service Accounts → Create

# Set token in systemd (admin)
sudo systemctl edit devbox-secrets.service
# Add: Environment="OP_SERVICE_ACCOUNT_TOKEN=your-token"
```

### 1.4 Verify Installation

```bash
# Check SSH access (from another machine)
ssh coal@orchestrator.tailnet

# Check Podman
podman --version
podman ps

# Check devbox-ctl
devbox-ctl --help
```

---

## 2. Dev Containers

Dev containers are created and managed via the orchestrator.

### 2.1 Create Your First Container

```bash
# SSH to orchestrator
ssh coal@orchestrator.tailnet

# Create a dev container
devbox-ctl create my-project

# Output:
# Creating container 'my-project'...
# Retrieving Tailscale auth key from 1Password...
# Starting container...
# Waiting for Tailscale connection...
#
# ✓ Container 'my-project' created successfully!
#
# Connect via SSH:    ssh dev@my-project
# Connect via Zed:    Open Zed → Connect to Server → dev@my-project
# Connect via Browser: https://my-project:8080 (code-server)
```

### 2.2 Connect to Container

**Via SSH (Tailscale)**:
```bash
ssh dev@my-project
# or with full tailnet domain
ssh dev@my-project.tailnet-name.ts.net
```

**Via Zed**:
1. Open Zed
2. Command Palette → "Connect to Server"
3. Enter: `dev@my-project`
4. Zed establishes SSH connection automatically

**Via code-server (browser)**:
1. Open browser to `http://my-project:8080`
2. Authenticate via Tailscale (automatic if on same tailnet)

### 2.3 Manage Containers

```bash
# List your containers
devbox-ctl list

# Stop a container (preserves data)
devbox-ctl stop my-project

# Start a stopped container
devbox-ctl start my-project

# View container details
devbox-ctl status my-project

# Destroy container (permanent)
devbox-ctl destroy my-project
```

### 2.4 Enable File Sync with Syncthing (Optional)

Create a container with Syncthing for bidirectional file sync with your local machine:

```bash
# Create container with Syncthing enabled
devbox-ctl create my-project --with-syncthing

# Output includes Syncthing URLs:
# Syncthing enabled:
#   GUI:        http://my-project:8384
#   Sync folder: /home/dev/sync
```

**One-time pairing setup:**

1. Open Syncthing GUI in browser: `http://my-project.tailnet:8384`
2. Note the container's Device ID (shown on main page)
3. On your Mac, open local Syncthing (install via `brew install syncthing` or nix-darwin)
4. Add Remote Device → paste container's Device ID
5. In container's Syncthing GUI, accept the pairing request
6. Share the "sync" folder bidirectionally

**After pairing:**

```bash
# On your Mac - files here sync to container
ls ~/Sync/

# In container - same files appear here
ssh dev@my-project
ls ~/sync/

# Edit on either side - changes sync within seconds
```

**Sync workflow:**

| Scenario | What Happens |
|----------|--------------|
| Edit file on Mac | Syncs to container `/home/dev/sync` in ~2 seconds |
| Edit file in container | Syncs to Mac `~/Sync` in ~2 seconds |
| Container stopped | Edits queue locally, sync when container restarts |
| Container destroyed (with `--keep-volume`) | Syncthing config preserved, pairing survives |

**Conflict handling:**

If the same file is edited on both sides simultaneously, Syncthing creates a `.sync-conflict-*` file. Resolve manually by keeping the version you want.

### 2.5 Container Limits

| Limit | Value | Notes |
|-------|-------|-------|
| Per user | 5 containers | Adjustable in config |
| Global | 7 containers | Based on host resources |
| CPU per container | 2 cores | Default, adjustable at creation |
| Memory per container | 4GB | Default, adjustable at creation |
| Idle timeout | 7 days | Auto-stop after inactivity |
| Stopped timeout | 14 days | Auto-destroy stopped containers |

---

## 3. macOS Workstation (nix-darwin)

Local development environment for macOS with Aerospace tiling.

### 3.1 Install Nix

```bash
# Using Determinate Systems installer (recommended)
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

# Restart terminal, verify
nix --version
```

### 3.2 Clone and Deploy

```bash
# Clone repository
git clone https://github.com/yourusername/nix-devbox.git
cd nix-devbox

# First-time nix-darwin bootstrap
nix run nix-darwin -- switch --flake .#macbook

# Subsequent updates
darwin-rebuild switch --flake .#macbook
```

### 3.3 Verify Installation

```bash
# Check CLI tools
which rg fd bat eza

# Check Aerospace
aerospace --version

# Aerospace should start automatically
# If not: open -a Aerospace
```

### 3.4 Aerospace Basics

| Keybinding | Action |
|------------|--------|
| `Alt + H/J/K/L` | Focus left/down/up/right |
| `Alt + Shift + H/J/K/L` | Move window left/down/up/right |
| `Alt + 1-9` | Switch to workspace 1-9 |
| `Alt + Shift + 1-9` | Move window to workspace 1-9 |
| `Alt + F` | Toggle fullscreen |
| `Alt + T` | Toggle float |

Configuration: `~/.config/aerospace/aerospace.toml`

---

## 4. Headful NixOS Desktop

Local Linux development environment with Hyprland tiling.

### 4.1 Prerequisites

- Bare-metal hardware (no VM, no WSL2)
- Compatible GPU (AMD or Intel recommended, NVIDIA requires extra config)
- NixOS 25.05 installation media

### 4.2 Installation

```bash
# Boot NixOS installer, set up partitions, then:

# Clone repository
nix-shell -p git
git clone https://github.com/yourusername/nix-devbox.git /mnt/etc/nixos/nix-devbox
cd /mnt/etc/nixos/nix-devbox

# Generate hardware config
nixos-generate-config --root /mnt
cp /mnt/etc/nixos/hardware-configuration.nix hosts/devbox-desktop/

# Install
nixos-install --flake .#devbox-desktop

# Reboot
reboot
```

### 4.3 Post-Install

```bash
# Login at TTY or display manager
# Hyprland should start automatically

# If not, from TTY:
Hyprland
```

### 4.4 Hyprland Basics

| Keybinding | Action |
|------------|--------|
| `Super + H/J/K/L` | Focus left/down/up/right |
| `Super + Shift + H/J/K/L` | Move window left/down/up/right |
| `Super + 1-9` | Switch to workspace 1-9 |
| `Super + Shift + 1-9` | Move window to workspace 1-9 |
| `Super + Enter` | Open terminal |
| `Super + D` | Application launcher |
| `Super + Q` | Close window |
| `Super + F` | Toggle fullscreen |
| `Super + V` | Toggle float |

Configuration: `~/.config/hypr/hyprland.conf`

---

## Troubleshooting

### Orchestrator

**SSH connection refused**:
```bash
# Check SSH service
sudo systemctl status sshd

# Check firewall
sudo iptables -L -n | grep 22

# Verify Tailscale is connected
tailscale status
```

**1Password CLI fails**:
```bash
# Check authentication
op account list

# Check service account token
echo $OP_SERVICE_ACCOUNT_TOKEN | op user get --me

# Re-authenticate
op signin
```

### Dev Containers

**Container creation timeout**:
```bash
# Check Podman
podman ps -a
podman logs <container-id>

# Check Tailscale inside container
podman exec <container-id> tailscale status
```

**Tailscale not connecting**:
```bash
# Verify auth key is valid in 1Password
op read "op://DevBox/coal-tailscale/authkey"

# Check container logs
devbox-ctl logs my-project

# Manual Tailscale check
podman exec my-project tailscale status
```

### macOS

**nix-darwin build fails**:
```bash
# Clear Nix cache
nix-collect-garbage -d

# Rebuild with verbose
darwin-rebuild switch --flake .#macbook --show-trace
```

**Aerospace not starting**:
```bash
# Check if running
pgrep -x Aerospace

# Start manually
open -a Aerospace

# Check logs
cat ~/Library/Logs/Aerospace/aerospace.log
```

### Headful NixOS

**Hyprland doesn't start**:
```bash
# Check GPU driver
lspci -k | grep -A 3 VGA

# Check Hyprland logs
cat ~/.local/share/hyprland/hyprland.log

# Try from TTY
Hyprland 2>&1 | tee ~/hyprland-debug.log
```

**Black screen after login**:
```bash
# Switch to TTY: Ctrl+Alt+F2
# Check for GPU issues
journalctl -b | grep -i gpu
journalctl -b | grep -i drm
```

---

## Common Tasks

### Update All Configurations

```bash
cd nix-devbox
git pull

# Orchestrator (bare-metal)
sudo nixos-rebuild switch --flake .#devbox

# Orchestrator (WSL2)
sudo nixos-rebuild switch --flake .#devbox-wsl

# macOS
darwin-rebuild switch --flake .#macbook

# Headful NixOS
sudo nixos-rebuild switch --flake .#devbox-desktop
```

### Add New User to Orchestrator

**In your private consumer repo:**

1. Edit `users.nix`:
```nix
newuser = {
  name = "newuser";
  uid = 1003;
  email = "newuser@example.com";
  gitUser = "newuser-github";
  isAdmin = false;
  sshKeys = [ "ssh-ed25519 AAAA..." ];
  extraGroups = [];
};

# Update collection fields
allUserNames = [ "existinguser" "newuser" ];
```

2. Create Tailscale auth key (see below)

3. Create 1Password item (see below)

4. Rebuild orchestrator

### Consumer Setup: 1Password Service Account

**One-time setup for your orchestrator:**

1. Go to [1Password → Settings → Developer → Service Accounts](https://my.1password.com/)
2. Create Service Account with:
   - Name: `devbox-orchestrator`
   - Vault access: Read access to your vault (e.g., `DevBox`)
3. Copy the token (starts with `ops_...`)
4. Store token securely on orchestrator:
```bash
# Option A: systemd credential (recommended)
sudo systemctl edit devbox-secrets.service
# Add: Environment="OP_SERVICE_ACCOUNT_TOKEN=ops_xxxxx..."

# Option B: agenix/sops-nix (if already using)
# Add to your secrets configuration
```

### Consumer Setup: Tailscale Auth Keys

**For each user, create an auth key:**

1. Go to [Tailscale Admin Console → Settings → Keys](https://login.tailscale.com/admin/settings/keys)
2. Generate auth key with:
   - Reusable: ✅ Yes
   - Ephemeral: ✅ Yes  
   - Tags: `tag:devcontainer`, `tag:{username}-container`
   - Expiry: 90 days (recommended)
3. Store in 1Password:
   - Vault: Your configured vault (e.g., `DevBox`)
   - Item name: `{username}-tailscale-authkey` (e.g., `coal-tailscale-authkey`)
   - Field: `password` = the auth key value

**Example 1Password CLI:**
```bash
op item create \
  --vault="DevBox" \
  --category=password \
  --title="coal-tailscale-authkey" \
  password="tskey-auth-xxxxxxxxxxxx..."
```

### Consumer Setup: Tailscale ACLs

**In your homelab-iac (or Tailscale admin console):**

```json
{
  "tagOwners": {
    "tag:devcontainer": ["autogroup:admin"],
    "tag:coal-container": ["group:admins"],
    "tag:violino-container": ["group:admins"]
  },
  "acls": [
    // Users can only SSH to their own containers
    {"action": "accept", "src": ["coal@github"], "dst": ["tag:coal-container:*"]},
    {"action": "accept", "src": ["violino@github"], "dst": ["tag:violino-container:*"]},
    
    // All containers can reach internet for package installs
    {"action": "accept", "src": ["tag:devcontainer"], "dst": ["*:443", "*:80"]}
  ]
}
```

### Consumer Setup: users.nix containers config

**In your private `users.nix`:**

```nix
{
  # ... user definitions ...

  containers = {
    opVault = "YourVaultName";  # Your actual 1Password vault
    maxPerUser = 5;
    maxGlobal = 7;
    defaultCpu = 2;
    defaultMemory = "4G";
    idleStopDays = 7;
    stoppedDestroyDays = 14;
  };
}
```

---

## Next Steps

- Review [CLI Contract](./contracts/README.md) for full command reference
- Review [Data Model](./data-model.md) for entity details
- Review [Research](./research.md) for technical decisions