# Quickstart: Devbox Skeleton

**Feature**: 001-devbox-skeleton
**Date**: 2026-01-17

## Prerequisites

Before deploying the devbox skeleton, ensure you have:

1. **Tailscale account** - Sign up at https://tailscale.com if needed
2. **SSH key pair** - Ed25519 recommended: `ssh-keygen -t ed25519`
3. **Target machine** - Fresh NixOS installation or installable hardware
4. **This repository** cloned locally

## Deployment Options

### Option A: Fresh NixOS Installation

1. Boot NixOS installer on target machine
2. Partition disks and mount at `/mnt`
3. Generate hardware config:
   ```bash
   nixos-generate-config --root /mnt
   ```
4. Copy `hardware-configuration.nix` to `hosts/devbox/`
5. Install with flake:
   ```bash
   nixos-install --flake github:ColeB1722/nix-devbox#devbox
   ```
6. Reboot

### Option B: Existing NixOS System

1. Clone repository:
   ```bash
   git clone https://github.com/ColeB1722/nix-devbox.git
   cd nix-devbox
   ```
2. Copy your hardware config:
   ```bash
   cp /etc/nixos/hardware-configuration.nix hosts/devbox/
   ```
3. Update your SSH public key in `modules/user/default.nix`
4. Build and switch:
   ```bash
   sudo nixos-rebuild switch --flake .#devbox
   ```

## Post-Deployment Setup

### 1. Authenticate Tailscale

After first boot, SSH in via local network or console and run:

```bash
sudo tailscale up
```

Follow the URL to authenticate. Once connected, note your Tailscale IP:

```bash
tailscale ip -4
```

### 2. Verify SSH Access via Tailscale

From another machine on your tailnet:

```bash
ssh user@<tailscale-ip>
```

### 3. Verify Security Configuration

The devbox includes built-in security assertions that are verified at build time.
Run these commands to verify the security configuration:

**Verify firewall is enabled:**
```bash
sudo systemctl status firewalld || sudo iptables -L -n
# Firewall should be active with default-deny policy
```

**Verify no public ports are exposed:**
```bash
sudo ss -tlnp
# Should show SSH listening, but only accessible via tailscale0
```

**Confirm password auth is rejected:**
```bash
ssh -o PreferredAuthentications=password devuser@<tailscale-ip>
# Should fail with "Permission denied (publickey)"
```

**Confirm root login is rejected:**
```bash
ssh root@<tailscale-ip>
# Should fail with "Permission denied"
```

**Verify Tailscale-only SSH access:**
```bash
# From outside the tailnet (e.g., public IP), SSH should timeout/fail
ssh devuser@<public-ip>
# Should fail - port 22 not exposed publicly
```

**Check SSH configuration:**
```bash
sudo sshd -T | grep -E 'passwordauthentication|permitrootlogin'
# Should show: passwordauthentication no, permitrootlogin no
```

## Configuration Customization

### Adding Your SSH Key

Edit `modules/user/default.nix`:

```nix
users.users.youruser.openssh.authorizedKeys.keys = [
  "ssh-ed25519 AAAAC3Nza... your-key-comment"
];
```

### Changing Timezone

Edit `modules/core/default.nix`:

```nix
time.timeZone = "America/New_York";  # or your timezone
```

### Adding Packages

User packages in `home/default.nix`:
```nix
home.packages = with pkgs; [
  htop
  tmux
  # add more here
];
```

System packages in `modules/core/default.nix`:
```nix
environment.systemPackages = with pkgs; [
  vim
  git
  # add more here
];
```

## Applying Changes

After editing configuration:

```bash
sudo nixos-rebuild switch --flake .#devbox
```

To test without switching:
```bash
nixos-rebuild build --flake .#devbox
```

## Rollback

If a configuration breaks the system:

### Method 1: From shell
```bash
sudo nixos-rebuild switch --rollback
```

### Method 2: At boot
Select a previous generation from the boot menu.

## Troubleshooting

### Can't SSH after Tailscale setup
- Verify tailscale is connected: `tailscale status`
- Check firewall allows tailscale0: `sudo iptables -L -n | grep tailscale`
- Verify SSH is running: `systemctl status sshd`

### Build fails with evaluation errors
- Check syntax: `nix flake check`
- Ensure hardware-configuration.nix exists in `hosts/devbox/`

### Tailscale won't authenticate
- Check internet connectivity
- Try `sudo tailscale up --reset`
- Verify no firewall blocking outbound HTTPS

## Next Steps

After skeleton deployment:
1. Add development tools via new modules
2. Configure editor/IDE settings in Home Manager
3. Add language toolchains as needed
4. Consider secret management (agenix/sops-nix) for sensitive config
