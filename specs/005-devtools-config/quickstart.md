# Quickstart: Development Tools and Configuration

**Feature**: 005-devtools-config  
**Date**: 2026-01-18

## Prerequisites

- NixOS devbox from feature 001 deployed and accessible via SSH
- Tailscale connected to the devbox
- SSH key configured in `modules/user/default.nix`

---

## Deployment

### 1. Build the Configuration

```bash
# On your local machine or the devbox
cd /path/to/nix-devbox

# Verify the configuration builds
nix flake check
nixos-rebuild build --flake .#devbox
```

### 2. Deploy to Devbox

```bash
# On the devbox (via SSH)
sudo nixos-rebuild switch --flake .#devbox

# Or for WSL
sudo nixos-rebuild switch --flake .#devbox-wsl
```

### 3. Re-login for Shell Change

After deployment, log out and log back in to activate fish as your default shell:

```bash
exit
ssh devbox  # Reconnect
```

You should now be in a fish shell.

---

## Verification Checklist

### Shell Environment

```bash
# Verify fish is active
echo $SHELL
# Expected: /run/current-system/sw/bin/fish

# Test CLI tools
tree --version
rg --version
fzf --version
bat --version
fd --version
eza --version

# Test fzf integration
# Press Ctrl+R for history search
# Press Ctrl+T for file search
```

### Docker

```bash
# Verify Docker works without sudo
docker ps
docker run hello-world

# Verify Docker Compose
docker compose version
```

### AI Tools

```bash
# OpenCode
opencode --version
# First run will prompt for setup

# Claude Code
claude --version
# First run will prompt for authentication
```

### Remote IDE

```bash
# code-server should be running
systemctl status code-server
curl http://localhost:8080

# Access via browser (through Tailscale)
# https://<devbox-tailscale-ip>:8080
# Or use: tailscale serve --bg 8080
```

### Zed Remote

On your local machine with Zed installed:

1. Open Zed
2. Go to **File > Connect to Server**
3. Enter: `ssh://devuser@<devbox-tailscale-hostname>`
4. Zed should connect and use the pre-installed remote server

### Terminal Multiplexer

```bash
# Start zellij
zellij

# Create new pane: Ctrl+P, N
# Split horizontally: Ctrl+P, D
# Switch panes: Ctrl+P, arrow keys
# Detach: Ctrl+P, D
# List sessions: zellij ls
# Reattach: zellij attach
```

### Version Control

```bash
# Test lazygit
cd /path/to/any/git/repo
lazygit

# Test GitHub CLI
gh auth login
gh auth status
```

### Package Managers

```bash
# npm
npm --version
npx --version

# uv (Python)
uv --version
uv pip --help
```

### Infrastructure Tools

```bash
# Terraform
terraform version
```

### Secrets Management

```bash
# 1Password CLI
op --version

# First-time authentication
op signin
# Or use service account:
# export OP_SERVICE_ACCOUNT_TOKEN="..."
```

---

## First-Time Setup Tasks

### 1. Configure Git Identity

Edit `home/default.nix` to set your git identity:

```nix
programs.git = {
  userName = "Your Name";
  userEmail = "your.email@example.com";
};
```

Then rebuild: `sudo nixos-rebuild switch --flake .#devbox`

### 2. GitHub CLI Authentication

```bash
gh auth login
# Follow the prompts to authenticate via browser or token
```

### 3. 1Password CLI Setup

```bash
# Interactive signin
op signin

# Or configure service account for automation
export OP_SERVICE_ACCOUNT_TOKEN="your-token"
op read "op://vault/item/field"
```

### 4. AI Tools Configuration

#### OpenCode
```bash
opencode
# Follow first-run setup wizard
```

#### Claude Code
```bash
claude
# Authenticate with your Anthropic account
```

### 5. code-server Extensions

Access code-server at `http://localhost:8080` and install extensions:

1. Nix IDE (`jnoortheen.nix-ide`)
2. Any language-specific extensions you need

### 6. Zed Remote (Client Setup)

On your local machine, configure Zed's SSH connections in `~/.config/zed/settings.json`:

```json
{
  "ssh_connections": [
    {
      "host": "devbox",
      "username": "devuser",
      "projects": [
        { "paths": ["~/projects"] }
      ]
    }
  ]
}
```

---

## CodeRabbit Setup

CodeRabbit is configured per-repository, not at the system level.

### 1. Enable CodeRabbit GitHub App

1. Go to [coderabbit.ai](https://coderabbit.ai)
2. Install the GitHub App for your repository
3. Configure review settings in the web UI

### 2. Repository Configuration (Optional)

Create `.coderabbit.yaml` in your repository root:

```yaml
# .coderabbit.yaml
language: en
reviews:
  request_changes_workflow: false
  high_level_summary: true
  poem: false
  review_status: true
  collapse_walkthrough: true
  path_filters: []
  path_instructions: []
chat:
  auto_reply: true
```

---

## Troubleshooting

### Fish shell not active after login

```bash
# Verify fish is in /etc/shells
cat /etc/shells | grep fish

# Verify user shell is set
getent passwd devuser | cut -d: -f7
# Should show: /run/current-system/sw/bin/fish

# If not, rebuild and re-login
sudo nixos-rebuild switch --flake .#devbox
exit
# Reconnect via SSH
```

### Docker permission denied

```bash
# Verify group membership
groups
# Should include: docker

# If not, the module may not be imported correctly
# Check hosts/devbox/default.nix includes modules/docker

# After fixing, rebuild and re-login (group changes need new session)
sudo nixos-rebuild switch --flake .#devbox
exit
# Reconnect
```

### code-server not accessible

```bash
# Check service status
systemctl status code-server
journalctl -u code-server -f

# Verify binding
ss -tlnp | grep 8080

# If accessing via Tailscale, ensure you're using the Tailscale IP
tailscale ip -4
```

### Zed remote connection fails

1. Verify Zed version matches on both sides
2. Check `~/.zed_server` exists and contains binaries
3. Ensure SSH works: `ssh devuser@devbox`
4. Check Zed logs on client

### fzf keybindings not working

```bash
# Verify fzf is configured for fish
cat ~/.config/fish/config.fish | grep fzf

# Reload fish config
source ~/.config/fish/config.fish

# Or restart shell
exec fish
```

---

## Useful Commands Reference

| Command | Description |
|---------|-------------|
| `just check` | Run flake checks |
| `just build` | Build NixOS configuration |
| `just deploy` | Deploy configuration |
| `just fmt` | Format Nix files |
| `just lint` | Run linters |
| `zellij` | Start terminal multiplexer |
| `lg` | Lazygit (abbreviation) |
| `gst` | Git status (abbreviation) |
| `nrs` | NixOS rebuild switch (abbreviation) |
