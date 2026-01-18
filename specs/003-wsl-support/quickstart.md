# WSL Support - Quickstart Guide

Deploy NixOS on Windows Subsystem for Linux as a remote development server.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     Windows Host                             │
│                                                              │
│  ┌─────────────────────────────────────────────────────────┐│
│  │                       WSL2                               ││
│  │  ┌─────────────────────────────────────────────────────┐││
│  │  │                   NixOS-WSL                         │││
│  │  │                                                     │││
│  │  │  ┌─────────────┐  ┌───────────┐  ┌────────────┐   │││
│  │  │  │  Tailscale  │  │  SSH      │  │  Dev Tools │   │││
│  │  │  │  (userspace)│  │  Server   │  │  (neovim,  │   │││
│  │  │  │  tag:shared │  │           │  │  tmux, etc)│   │││
│  │  │  └─────────────┘  └───────────┘  └────────────┘   │││
│  │  │        │                                           │││
│  │  └────────┼───────────────────────────────────────────┘││
│  └───────────┼─────────────────────────────────────────────┘│
└──────────────┼──────────────────────────────────────────────┘
               │
          Tailscale Network (100.x.x.x)
               │
┌──────────────┴──────────────┐
│  Your Laptop (any OS)       │
│                             │
│  ssh devuser@devbox-wsl     │
└─────────────────────────────┘
```

**Key point:** Tailscale runs *inside* WSL (not on Windows), giving WSL its own Tailscale identity.

## Prerequisites

- Windows 10/11 with WSL2 enabled
- PowerShell (for initial setup)
- Access to homelab-iac repo (for Tailscale auth key)

## Installation

### Step 1: Enable WSL2 (if not already enabled)

```powershell
# Run in PowerShell as Administrator
wsl --install --no-distribution
# Reboot if prompted
```

### Step 2: Install NixOS-WSL

```powershell
# Download NixOS-WSL 25.05 release from:
# https://github.com/nix-community/NixOS-WSL/releases

# Import into WSL
wsl --import NixOS $env:USERPROFILE\NixOS $env:USERPROFILE\Downloads\nixos-wsl.tar.gz --version 2

# Start NixOS
wsl -d NixOS
```

### Step 3: Initial NixOS Setup

Inside the NixOS WSL shell:

```bash
# Set a password for the nixos user
sudo passwd nixos

# Update channels (required for first rebuild)
sudo nix-channel --update

# Enable flakes
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" > ~/.config/nix/nix.conf
```

### Step 4: Deploy Configuration from FlakeHub

```bash
sudo nixos-rebuild switch --flake "https://flakehub.com/f/coal-bap/nix-devbox/*#devbox-wsl"
```

This will:
- Create the `devuser` account
- Install all dev tools (neovim, tmux, git, etc.)
- Configure SSH with key-based auth
- Install Tailscale (in userspace mode)

After rebuild, exit and re-enter WSL to switch to `devuser`:
```bash
exit
```

Then from PowerShell:
```powershell
wsl -d NixOS
```

### Step 5: Authenticate Tailscale

Get the shared auth key from homelab-iac (on your Mac or another machine):

```bash
cd ~/repos/homelab-iac
just output tailscale shared_auth_key
```

Then in WSL, authenticate Tailscale:

```bash
sudo tailscale up --authkey=<paste-the-key>
```

Verify the connection:

```bash
# Check status
tailscale status

# Get your Tailscale IP
tailscale ip -4

# Note: Your hostname will be 'devbox-wsl' on the tailnet
```

### Step 6: Connect via SSH

From any machine on your tailnet:

```bash
# Using Tailscale hostname
ssh devuser@devbox-wsl

# Or using Tailscale IP
ssh devuser@100.x.x.x
```

## Updating the Configuration

When updates are pushed to the repo:

```bash
# Pull latest from FlakeHub
sudo nixos-rebuild switch --flake "https://flakehub.com/f/coal-bap/nix-devbox/*#devbox-wsl"
```

Or if you have the repo cloned locally:

```bash
cd ~/nix-devbox
git pull
sudo nixos-rebuild switch --flake .#devbox-wsl
```

## Key Differences from Bare-Metal

| Feature | Bare-Metal (devbox) | WSL (devbox-wsl) |
|---------|---------------------|------------------|
| Hardware config | Required | Not needed |
| Bootloader | GRUB/systemd-boot | Windows handles |
| Tailscale | Kernel WireGuard | Userspace networking |
| Tailscale tag | `tag:server` | `tag:shared` |
| Networking | Full control | WSL manages |

## Troubleshooting

### SSH Connection Refused

1. Verify WSL is running: `wsl -l -v` (should show NixOS as Running)
2. Check SSH service: `sudo systemctl status sshd`
3. Verify firewall allows SSH: `sudo iptables -L -n`

### Tailscale Not Connecting

```bash
# Check Tailscale status
tailscale status

# Check for errors in logs
sudo journalctl -u tailscaled -f

# Re-authenticate if needed
sudo tailscale up --authkey=<key>
```

### Tailscale Shows "offline" or "relay"

Userspace networking in WSL may use DERP relays more often. This is normal and functional, just slightly higher latency than direct connections.

### WSL Networking Issues

```powershell
# Restart WSL networking
wsl --shutdown
wsl -d NixOS
```

### Rebuild Fails

```bash
# Show full error trace
sudo nixos-rebuild switch --flake .#devbox-wsl --show-trace

# Update flake inputs
nix flake update
```

## File Locations

| Purpose | Path |
|---------|------|
| NixOS config | `/etc/nixos` (symlink) or `~/nix-devbox` |
| User home | `/home/devuser` |
| Tailscale state | `/var/lib/tailscale` |
| Windows C: drive | `/mnt/c` |
| Windows home | `/mnt/c/Users/<username>` |

## Security Notes

- **Tailscale ACLs:** WSL uses `tag:shared` which allows SSH access from authorized users only
- **SSH keys:** Managed declaratively in `modules/user/default.nix`
- **Windows isolation:** Windows host is NOT on the tailnet; only WSL is exposed
