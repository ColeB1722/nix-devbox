# Quickstart: Multi-User Support

**Feature**: 006-multi-user-support  
**Date**: 2026-01-18

## Prerequisites

- NixOS devbox deployed (feature 001)
- Development tools configured (feature 005)
- SSH public keys for both users:
  - coal's key (already in use)
  - violino's key (obtain from violino)

## Environment Setup

### 1. Obtain SSH Public Keys

**coal's key** (existing):
```bash
# Already configured, verify with:
cat ~/.ssh/id_ed25519.pub
# Example: ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... coal@machine
```

**violino's key** (obtain from user):
```bash
# violino should run on their machine:
cat ~/.ssh/id_ed25519.pub
# Or generate if needed:
ssh-keygen -t ed25519 -C "violinomaestro@gmail.com"
```

### 2. Set Environment Variables

**Option A: Local .env file (for local deploys)**

Create `.env` in repo root (gitignored):
```bash
# .env
SSH_KEY_COAL="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI..."
SSH_KEY_VIOLINO="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI..."
```

With direnv:
```bash
# .envrc
dotenv
```

**Option B: Export directly (temporary)**
```bash
export SSH_KEY_COAL="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI..."
export SSH_KEY_VIOLINO="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI..."
```

**Option C: CI/CD secrets (for automated deploys)**

In GitHub Actions:
1. Go to repo Settings → Secrets and variables → Actions
2. Add repository secrets:
   - `SSH_KEY_COAL`: coal's full public key
   - `SSH_KEY_VIOLINO`: violino's full public key
3. Use in deploy workflow (NOT publish workflow)

## Deployment

### Local Deployment (on devbox)

```bash
# 1. Clone/update repo
cd /path/to/nix-devbox
git pull

# 2. Ensure env vars are set
echo $SSH_KEY_COAL    # Should show key
echo $SSH_KEY_VIOLINO # Should show key

# 3. Build and switch
sudo nixos-rebuild switch --flake .#devbox

# 4. Verify users created
id coal
id violino
```

### Remote Deployment (from another machine)

```bash
# With env vars set locally
nixos-rebuild switch \
  --flake .#devbox \
  --target-host coal@devbox.tailnet \
  --use-remote-sudo
```

### WSL Deployment

```bash
# Inside WSL
sudo nixos-rebuild switch --flake .#devbox-wsl
```

## Verification Checklist

### User Accounts

```bash
# Check users exist
id coal
# Expected: uid=1000(coal) gid=100(users) groups=100(users),27(sudo),998(docker)

id violino
# Expected: uid=1001(violino) gid=100(users) groups=100(users),998(docker)

# Check home directories
ls -la /home/
# Expected: drwx------ coal, drwx------ violino

# Check shells
getent passwd coal | cut -d: -f7
# Expected: /run/current-system/sw/bin/fish
```

### SSH Access

```bash
# As coal (from another machine on tailnet)
ssh coal@devbox.tailnet
# Should succeed with coal's key

# As Violino (from another machine on tailnet)
ssh violino@devbox.tailnet
# Should succeed with Violino's key
```

### Sudo Access

```bash
# As coal
sudo whoami
# Expected: root (no password prompt)

# As Violino
sudo whoami
# Expected: Permission denied or password prompt (she's not in wheel)
```

### Docker Access

```bash
# As coal
docker ps
# Should work without sudo

# As Violino  
docker ps
# Should work without sudo (both in docker group)
```

### code-server Access

Access is controlled by Tailscale ACLs (defined in `homelab-iac/tailscale/main.tf`).

```bash
# Check services running
systemctl status code-server-coal
systemctl status code-server-violino

# Access directly via Tailscale (no tunnel needed)
# coal (admin) - can access both instances:
#   http://devbox:8080  (coal's instance)
#   http://devbox:8081  (violino's instance, for troubleshooting)

# violino (user) - can only access their instance:
#   http://devbox:8081
```

**Note:** Access requires:
1. Device is on the Tailscale network
2. User has appropriate ACL permissions in homelab-iac

### Home Manager Environments

```bash
# As coal
fish --version
fzf --version
bat --version
eza --version

# Check git config
git config user.name
# Expected: coal-bap

# As violino
su - violino
git config user.name
# Expected: Violino
```

## Troubleshooting

### Build succeeds but SSH login fails

If you see this warning during build:
```
warning: SSH_KEY_COAL not set - using placeholder (deploy will fail)
```

And then SSH login fails with "Permission denied (publickey)":

**Cause**: Environment variables were not set, so placeholder keys were used.

**Solution**: 
```bash
# 1. Set environment variables
source .env  # or export manually

# 2. Verify they're set
echo $SSH_KEY_COAL | head -c 30
# Should show: ssh-ed25519 AAAA...

# 3. Rebuild with -E to preserve env for sudo
sudo -E nixos-rebuild switch --flake .#devbox
```

### Strict mode for deployment safety

To fail the build if keys are missing (recommended for production deploys):

```bash
export NIX_STRICT_KEYS=true
export SSH_KEY_COAL="ssh-ed25519 AAAA..."
export SSH_KEY_VIOLINO="ssh-ed25519 AAAA..."
sudo -E nixos-rebuild switch --flake .#devbox
```

This will cause an assertion failure if any key is missing, preventing accidental deploys with placeholder keys.

### User can't SSH in

1. Check key format:
   ```bash
   echo $SSH_KEY_COAL | head -c 20
   # Should start with: ssh-ed25519 AAAA
   ```

2. Check authorized_keys on devbox:
   ```bash
   cat /home/coal/.ssh/authorized_keys
   # Should contain the key
   ```

3. Check SSH daemon logs:
   ```bash
   journalctl -u sshd -f
   ```

### code-server not accessible

1. Check service status:
   ```bash
   systemctl status code-server-coal
   systemctl status code-server-violino
   ```

2. Check port binding:
   ```bash
   ss -tlnp | grep -E '8080|8081'
   ```

3. Verify Tailscale is running:
   ```bash
   tailscale status
   ```

### Home Manager conflicts

If you see "collision" errors during rebuild:
```bash
# Check for conflicting files
home-manager generations

# Remove old generations if needed
home-manager remove-generations old
```

## FlakeHub Safety

**Important**: When publishing to FlakeHub, do NOT set SSH key environment variables.

```yaml
# CI workflow - publish job should NOT have these secrets
publish:
  steps:
    - run: nix flake check  # No SSH_KEY_* vars
    - uses: flakehub-push   # Safe to publish
```

The published flake will have empty SSH keys, which is safe. Real keys are only injected during actual deployment.

## Adding a New User (Future)

To add a third user:

1. Add environment variable:
   ```bash
   export SSH_KEY_NEWUSER="ssh-ed25519 AAAA..."
   ```

2. Add user definition in `modules/user/default.nix`:
   ```nix
   users.users.newuser = {
     isNormalUser = true;
     uid = 1002;
     # ...
   };
   ```

3. Create Home Manager config `home/newuser.nix`:
   ```nix
   { ... }: {
     imports = [ ./common.nix ];
     home.username = "newuser";
     # ...
   }
   ```

4. Rebuild:
   ```bash
   sudo nixos-rebuild switch --flake .#devbox
   ```
