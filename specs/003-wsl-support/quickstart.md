# WSL Support - Quickstart Guide

Deploy NixOS on Windows Subsystem for Linux as a remote development server.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     Windows Host                             │
│  ┌─────────────┐    ┌─────────────────────────────────────┐ │
│  │  Tailscale  │    │           WSL2                       │ │
│  │  (Windows)  │───▶│  ┌─────────────────────────────────┐ │ │
│  └─────────────┘    │  │         NixOS-WSL               │ │ │
│        ▲            │  │  ┌───────────┐  ┌────────────┐  │ │ │
│        │            │  │  │  SSH      │  │  Dev Tools │  │ │ │
│        │            │  │  │  Server   │  │  (neovim,  │  │ │ │
│        │            │  │  └───────────┘  │  tmux, etc)│  │ │ │
│        │            │  │                  └────────────┘  │ │ │
│        │            │  └─────────────────────────────────┘ │ │
│        │            └─────────────────────────────────────┘ │
└────────┼────────────────────────────────────────────────────┘
         │
    Tailscale Network (100.x.x.x)
         │
┌────────┴────────┐
│  Your Laptop    │
│  (any OS)       │
│                 │
│  ssh devuser@   │
│  windows-host   │
└─────────────────┘
```

## Prerequisites

- Windows 10/11 with WSL2 enabled
- Tailscale installed on Windows
- PowerShell (for initial setup)

## Installation

### Step 1: Enable WSL2 (if not already enabled)

```powershell
# Run in PowerShell as Administrator
wsl --install --no-distribution
# Reboot if prompted
```

### Step 2: Install NixOS-WSL

```powershell
# Download the latest NixOS-WSL release
# From: https://github.com/nix-community/NixOS-WSL/releases
# Download: nixos-wsl.tar.gz (for 2405.x releases)

# Import into WSL
wsl --import NixOS $env:USERPROFILE\NixOS .\nixos-wsl.tar.gz --version 2

# Start NixOS
wsl -d NixOS
```

### Step 3: Clone and Deploy Configuration

Inside the NixOS WSL shell:

```bash
# Set a password for the nixos user (temporary, will be replaced)
passwd

# Update channels (required for first rebuild)
sudo nix-channel --update

# Enable flakes
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" > ~/.config/nix/nix.conf

# Clone the configuration
cd ~
git clone https://github.com/coal-bap/nix-devbox.git
cd nix-devbox

# Deploy the WSL configuration
sudo nixos-rebuild switch --flake .#devbox-wsl
```

### Step 4: Configure Your SSH Key

Edit `modules/user/default.nix` and add your SSH public key:

```nix
openssh.authorizedKeys.keys = [
  # Replace with your actual SSH public key
  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA... your-email@example.com"
];
```

Then rebuild:

```bash
sudo nixos-rebuild switch --flake .#devbox-wsl
```

### Step 5: Setup Tailscale on Windows

1. Install Tailscale for Windows from https://tailscale.com/download
2. Sign in to your tailnet
3. Your Windows machine is now accessible via Tailscale

### Step 6: Connect via SSH

From any machine on your tailnet:

```bash
# Use your Windows machine's Tailscale hostname or IP
ssh devuser@your-windows-hostname

# Or use the Tailscale IP
ssh devuser@100.x.x.x
```

## Updating the Configuration

When you pull changes from the repo:

```bash
cd ~/nix-devbox
git pull
sudo nixos-rebuild switch --flake .#devbox-wsl
```

Or to pull directly from FlakeHub:

```bash
sudo nixos-rebuild switch --flake flakehub:coal-bap/nix-devbox#devbox-wsl
```

## Key Differences from Bare-Metal

| Feature | Bare-Metal (devbox) | WSL (devbox-wsl) |
|---------|---------------------|------------------|
| Hardware config | Required | Not needed |
| Bootloader | GRUB/systemd-boot | Windows handles |
| Tailscale | Runs in NixOS | Runs on Windows |
| Firewall | Tailscale-only | SSH open (Windows filters) |
| Networking | Full control | WSL manages |

## Troubleshooting

### SSH Connection Refused

1. Verify WSL is running: `wsl -l -v` (should show NixOS as Running)
2. Check SSH service: `sudo systemctl status sshd`
3. Verify firewall allows SSH: `sudo iptables -L -n`

### Tailscale Not Working

Tailscale should run on Windows, not in WSL. Verify:
1. Tailscale is running in Windows system tray
2. Windows machine appears in Tailscale admin console
3. WSL inherits Windows networking automatically

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

# Check for lock file issues
nix flake update
```

## File Locations

| Purpose | Path |
|---------|------|
| NixOS config | `/etc/nixos` (symlink) or `~/nix-devbox` |
| User home | `/home/devuser` |
| Windows C: drive | `/mnt/c` |
| Windows home | `/mnt/c/Users/<username>` |
