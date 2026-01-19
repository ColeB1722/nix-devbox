# WSL SSH Connection Troubleshooting

## Problem (RESOLVED)

SSH connections from Mac to `devbox-wsl` via Tailscale were hanging during key exchange at `expecting SSH2_MSG_KEX_ECDH_REPLY`. The connection established, KEXINIT messages exchanged, but the server never responded.

**Root Cause:** The `services.tailscale.interfaceName = "userspace-networking"` setting forced Tailscale into SOCKS5/HTTP proxy mode, which doesn't work with SSH.

**Solution:** Remove that setting. WSL2 supports TUN devices via `wireguard-go`, so Tailscale can create a proper `tailscale0` interface.

## Investigation Summary

### What We Ruled Out

| Cause | Status | Evidence |
|-------|--------|----------|
| Network/Tailscale connectivity | ✅ Working | `ping devbox-wsl` works, `nc -zv devbox-wsl 22` succeeds |
| Tailscale ACLs | ✅ Correct | User has full access to `tag:shared` |
| SSH key mismatch | ✅ Correct | 1Password agent has matching key |
| Entropy starvation | ✅ Not the issue | Kernel 6.6+ doesn't have this problem |
| NixOS firewall | ✅ Not the issue | SSH hangs even with firewall disabled |
| sshd configuration | ✅ Working | `ssh coal@localhost` works inside WSL |
| MTU issues | ✅ Already correct | MTU already set to 1280 |

### Root Cause: Tailscale Userspace Networking

The WSL configuration uses `services.tailscale.interfaceName = "userspace-networking"` because WSL2's Microsoft-provided kernel **does not include WireGuard**.

**Important distinction:**
- **wireguard-go** (userspace WireGuard) - Creates a TUN interface using userspace code. Acts like a normal network interface.
- **Tailscale userspace-networking** - Does NOT create a TUN interface. Runs as a **SOCKS5/HTTP proxy** instead.

From [Tailscale docs](https://tailscale.com/kb/1112/userspace-networking):
> "Userspace networking mode offers a different way of running, where `tailscaled` functions as a SOCKS5 or HTTP proxy which other processes in the container can connect through."

With userspace networking:
- **No `tailscale0` interface is created**
- Traffic must go through the SOCKS5/HTTP proxy explicitly
- SSH doesn't automatically use the proxy - it tries to connect directly
- Known issues with packet handling cause SSH key exchange to hang
- This is a [documented issue](https://github.com/tailscale/tailscale/issues/4833)

### Why We Can't Fix It in NixOS Config

WSL2 uses **Microsoft's kernel**, not a NixOS-built kernel:
- Cannot add WireGuard via `boot.kernelModules`
- Cannot modify kernel configuration
- Kernel is fixed at: `6.6.87.2-microsoft-standard-WSL2`

## Solution: Use Default TUN Mode (wireguard-go) ✅ WORKING

WSL2 supports TUN devices via `/dev/net/tun`. Tailscale's `wireguard-go` creates a proper `tailscale0` interface without needing kernel WireGuard.

### What Was Wrong

The config had:
```nix
services.tailscale.interfaceName = "userspace-networking";
```

This forced Tailscale into proxy-only mode (no `tailscale0` interface), which broke SSH.

### The Fix

Remove that line from `hosts/devbox-wsl/default.nix`. Tailscale will default to creating a `tailscale0` interface using `wireguard-go`.

### Test Inside WSL (Already Verified Working)

```bash
# Stop current tailscale
sudo systemctl stop tailscaled

# Run tailscaled WITHOUT userspace-networking (default mode)
sudo tailscaled &

# Check if tailscale0 was created
ip link show | grep tailscale

# If it exists, authenticate
sudo tailscale up
```

If `tailscale0` appears, update the NixOS config:

```nix
# In hosts/devbox-wsl/default.nix

# REMOVE this line:
#   services.tailscale.interfaceName = "userspace-networking";

# Tailscale will use wireguard-go to create tailscale0
```

### Why This Works

- `wireguard-go` creates TUN interfaces without kernel WireGuard
- WSL2 kernel supports `/dev/net/tun` ✅
- This creates a real network interface that SSH uses directly
- Unlike `userspace-networking` which only provides a SOCKS5/HTTP proxy

## Alternative: Windows Tailscale + Port Forwarding (Not Needed)

This was the fallback plan, but Option 1 worked. Documenting for reference.

### Architecture Change

**Current (broken):**
```
Mac → Tailscale → WSL Tailscale (userspace-networking) → sshd
                  ↑ hangs here due to packet handling issues
```

**Proposed (working):**
```
Mac → Tailscale → Windows Tailscale → port forward → WSL sshd
```

### Implementation Steps

If Option 1 doesn't work, use Windows as the Tailscale endpoint.

#### 1. Remove Tailscale from WSL NixOS Config

```nix
# In hosts/devbox-wsl/default.nix

# REMOVE from imports:
#   ../../modules/networking/tailscale.nix

# REMOVE these options:
#   devbox.tailscale.enable = true;
#   services.tailscale.interfaceName = "userspace-networking";

# UPDATE firewall (remove non-existent interface):
networking.firewall = {
  enable = true;
  allowedTCPPorts = [ 22 ];
  # Remove: trustedInterfaces = [ "tailscale0" ];
};

# REMOVE (ineffective on kernel 6.6+):
#   services.haveged.enable = true;
```

#### 2. Enable Tailscale on Windows

- Install Tailscale on Windows
- Authenticate with `tag:shared` auth key from homelab-iac:
  ```bash
  cd ~/repos/homelab-iac && just output tailscale shared_auth_key
  ```

#### 3. Configure Windows Port Forwarding

PowerShell (Admin):
```powershell
# Get WSL IP
$wslIp = (wsl hostname -I).Trim().Split()[0]

# Forward port 22
netsh interface portproxy add v4tov4 listenport=22 listenaddress=0.0.0.0 connectport=22 connectaddress=$wslIp

# Verify
netsh interface portproxy show all
```

**Note:** WSL IP changes on restart. Consider a startup script:

```powershell
# Save as: C:\Scripts\wsl-port-forward.ps1
$wslIp = (wsl hostname -I).Trim().Split()[0]
netsh interface portproxy delete v4tov4 listenport=22 listenaddress=0.0.0.0
netsh interface portproxy add v4tov4 listenport=22 listenaddress=0.0.0.0 connectport=22 connectaddress=$wslIp
```

Add to Task Scheduler to run at login.

#### 4. Windows Firewall

Allow inbound SSH on Tailscale interface:
```powershell
New-NetFirewallRule -DisplayName "SSH over Tailscale" -Direction Inbound -Protocol TCP -LocalPort 22 -Action Allow
```

## Option 3: Custom WSL Kernel (Complex)

If you prefer Tailscale inside WSL with proper `tailscale0` interface:

1. Clone and compile custom kernel with WireGuard:
   ```bash
   git clone https://github.com/microsoft/WSL2-Linux-Kernel
   cd WSL2-Linux-Kernel
   # Enable CONFIG_WIREGUARD=y in Microsoft/config-wsl
   make -j$(nproc) KCONFIG_CONFIG=Microsoft/config-wsl
   ```

2. Configure Windows to use it in `%USERPROFILE%\.wslconfig`:
   ```ini
   [wsl2]
   kernel=C:\\path\\to\\WSL2-Linux-Kernel\\arch\\x86\\boot\\bzImage
   ```

3. Restart WSL: `wsl --shutdown`

## Summary of Options

| Option | Complexity | Reliability | Notes |
|--------|------------|-------------|-------|
| 1. Default TUN mode (wireguard-go) | Low | ✅ **WORKING** | Just remove `userspace-networking` setting |
| 2. Windows Tailscale + port forward | Medium | High | Not needed - Option 1 works |
| 3. Custom WSL kernel | High | High | Not needed - Option 1 works |

## Session Notes

- **Date:** 2024 (current session)
- **PR #8** (SSH key refactor) pending merge to main → FlakeHub
- **Issue #4** created for homelab-iac CI/CD work
- `haveged` was added to WSL config but is ineffective on kernel 6.6+
- Firewall `trustedInterfaces = [ "tailscale0" ]` is useless since interface doesn't exist

## Files Modified This Session

| File | Change |
|------|--------|
| `modules/user/default.nix` | Hardcoded SSH public keys (removed env var injection) |
| `hosts/devbox-wsl/default.nix` | Added haveged (ineffective, should remove) |
| `README.md` | Updated SSH key documentation |
| `AGENTS.md` | Removed .env.example reference |
| `.env.example` | Deleted (no longer needed) |
| `homelab-iac/CLAUDE.md` | Added Known Gaps section referencing issue #4 |

## Resolution Status

- [x] Identified root cause: `userspace-networking` setting
- [x] Tested fix: Removing setting allows `tailscale0` to be created
- [x] SSH works with proper TUN interface
- [x] Updated `hosts/devbox-wsl/default.nix` to remove broken setting
- [ ] Merge PR #8 to publish SSH key changes to FlakeHub
- [ ] Rebuild WSL with updated config: `sudo nixos-rebuild switch --flake .#devbox-wsl`
- [ ] Consider WSL keep-alive settings (`.wslconfig` with `vmIdleTimeout=-1`)