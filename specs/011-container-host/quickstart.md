# Quickstart: Container Host

**Feature**: 011-container-host  
**Date**: 2025-01-31

## Prerequisites

1. **Tailscale configured** with appropriate ACLs in the Tailscale admin console
2. **Tailscale client** installed and authenticated on your local machine
3. **Target machine** running NixOS 25.05+ with cgroups v2 enabled

## Deployment

### 1. Configure Tailscale ACLs (External)

In your Tailscale admin console, add the following ACL rules:

```json
{
  "tagOwners": {
    "tag:container-host": ["autogroup:admin"]
  },
  "ssh": [
    {
      "action": "check",
      "src": ["group:devs"],
      "dst": ["tag:container-host"],
      "users": ["autogroup:nonroot"]
    }
  ]
}
```

### 2. Define Users

Create or update your `users.nix` with resource quotas:

```nix
{
  alice = {
    name = "alice";
    uid = 1001;
    description = "Alice - Agent Developer";
    email = "alice@example.com";
    gitUser = "alice";
    isAdmin = false;
    sshKeys = [ ]; # Empty — Tailscale SSH handles auth
    extraGroups = [ ];
    resourceQuota = {
      cpuCores = 2;
      memoryGB = 4;
      storageGB = 50;
    };
  };

  admin = {
    name = "admin";
    uid = 1000;
    description = "Platform Admin";
    email = "admin@example.com";
    gitUser = "admin";
    isAdmin = true;
    sshKeys = [ ];
    extraGroups = [ ];
    # No resourceQuota — admins are unlimited
  };

  allUserNames = [ "admin" "alice" ];
  adminUserNames = [ "admin" ];
}
```

### 3. Deploy

```bash
sudo nixos-rebuild switch --flake .#container-host
```

### 4. Tag the Host in Tailscale

```bash
sudo tailscale up --advertise-tags=tag:container-host
```

## User Guide

### Connecting via SSH

```bash
# From any machine on your Tailnet
ssh alice@container-host

# Tailscale will prompt for OAuth if session expired
```

### Basic Container Operations

```bash
# Pull an image
podman pull docker.io/library/ubuntu:24.04

# Run a container
podman run -it --name myagent ubuntu:24.04 /bin/bash

# List your containers
podman ps -a

# Stop a container
podman stop myagent

# Remove a container
podman rm myagent

# Check your resource usage
podman system df
```

### Volume Mounts

Containers can only mount paths within your home directory:

```bash
# Allowed
podman run -v ~/projects:/workspace:Z ubuntu:24.04

# Blocked (outside home directory)
podman run -v /etc:/host-etc ubuntu:24.04  # Permission denied
```

## Admin Guide

### View All Users' Containers

```bash
# List containers for a specific user
sudo -u alice podman ps -a

# List all containers across all users (script)
for user in $(getent passwd | awk -F: '$3 >= 1000 && $3 < 65000 {print $1}'); do
  echo "=== $user ==="
  sudo -u "$user" podman ps -a 2>/dev/null || echo "No containers"
done
```

### Stop a Runaway Container

```bash
# Identify the user and container
sudo -u alice podman stop <container-id>

# Force kill if needed
sudo -u alice podman kill <container-id>
```

### Check Resource Usage

```bash
# View systemd slice for a user
systemctl status user-1001.slice

# View cgroup resource usage
systemd-cgtop

# View all user slices
systemd-cgls
```

### Check Filesystem Quotas

```bash
# View quota for a user
sudo repquota -u /home | grep alice

# Manually set quota (if not managed by Nix)
sudo setquota -u alice 50G 55G 0 0 /home
```

## Troubleshooting

### SSH Connection Refused

1. Verify Tailscale is running: `tailscale status`
2. Check host is tagged: `tailscale status | grep container-host`
3. Verify ACLs permit your identity in Tailscale admin console

### Container Permission Denied

1. Verify rootless Podman is initialized: `podman info`
2. Check subuid/subgid allocation: `grep $USER /etc/subuid /etc/subgid`
3. Re-initialize if needed: `podman system migrate`

### Resource Limit Hit

```bash
# Check if OOM killed
journalctl -u user@$(id -u) | grep -i oom

# Check cgroup limits
cat /sys/fs/cgroup/user.slice/user-$(id -u).slice/memory.max

# Check storage quota
quota -s
```

### Podman Socket Not Found

```bash
# Ensure user lingering is enabled (persists user services)
loginctl enable-linger $USER

# Start Podman socket
systemctl --user start podman.socket

# Verify socket exists
ls /run/user/$(id -u)/podman/podman.sock
```

## Security Notes

- **No `--privileged`**: Containers cannot run in privileged mode
- **No nested containers**: Podman-in-Podman is disabled
- **No host network**: Containers use slirp4netns or pasta for networking
- **No root containers**: All containers run rootless under user namespaces