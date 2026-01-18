# Module Interfaces: Multi-User Support

**Feature**: 006-multi-user-support  
**Date**: 2026-01-18

## Module: modules/user/default.nix

### Purpose
Define multiple user accounts with SSH key injection from environment variables.

### Interface

```nix
# Input: Environment variables (read at evaluation time)
# SSH_KEY_COAL    - coal's SSH public key
# SSH_KEY_VIOLINO - Violino's SSH public key

# Output: NixOS configuration
{
  users.users.coal = { ... };
  users.users.violino = { ... };
  home-manager.users.coal = import ../../home/coal.nix;
  home-manager.users.violino = import ../../home/violino.nix;
  security.sudo.wheelNeedsPassword = false;
  programs._1password.enable = true;
}
```

### Graceful Key Handling

```nix
let
  # Read keys from environment, use placeholder if not set
  coalKeyRaw = builtins.getEnv "SSH_KEY_COAL";
  violinoKeyRaw = builtins.getEnv "SSH_KEY_VIOLINO";
  
  # Placeholder allows builds to succeed for FlakeHub publish
  # Obviously invalid - SSH will reject, making the issue clear
  placeholder = "ssh-ed25519 PLACEHOLDER_KEY_NOT_SET_check_SSH_KEY_envvar";
  
  # Use real key if set, otherwise placeholder with warning
  coalKey = if coalKeyRaw != "" 
    then coalKeyRaw 
    else lib.warn "SSH_KEY_COAL not set - using placeholder (deploy will fail)" placeholder;
  
  violinoKey = if violinoKeyRaw != "" 
    then violinoKeyRaw 
    else lib.warn "SSH_KEY_VIOLINO not set - using placeholder (deploy will fail)" placeholder;
in
{
  users.users.coal.openssh.authorizedKeys.keys = [ coalKey ];
  users.users.violino.openssh.authorizedKeys.keys = [ violinoKey ];
}
```

### Assertions (Optional Strict Mode)

For strict validation during actual deploys, an optional assertion can be added:

```nix
assertions = lib.optionals (builtins.getEnv "NIX_STRICT_KEYS" == "true") [
  {
    assertion = builtins.getEnv "SSH_KEY_COAL" != "";
    message = "SSH_KEY_COAL must be set for deployment. Export the env var or use .env file.";
  }
  {
    assertion = builtins.getEnv "SSH_KEY_VIOLINO" != "";
    message = "SSH_KEY_VIOLINO must be set for deployment. Export the env var or use .env file.";
  }
];
```

**Behavior Matrix**:

| Scenario | SSH_KEY_* set? | NIX_STRICT_KEYS | Build Result | Deploy Result |
|----------|----------------|-----------------|--------------|---------------|
| FlakeHub publish | No | Not set | ✅ Success (placeholder) | N/A |
| Local test build | No | Not set | ✅ Success + warning | ❌ SSH fails (placeholder rejected) |
| Local deploy | Yes | Not set | ✅ Success | ✅ SSH works |
| Strict deploy | No | true | ❌ Assertion fails | N/A |
| Strict deploy | Yes | true | ✅ Success | ✅ SSH works |

### Dependencies
- `pkgs.fish` - Default shell
- Home Manager NixOS module
- `programs._1password` - 1Password CLI integration

---

## Module: home/common.nix

### Purpose
Shared Home Manager configuration imported by all user-specific configs.

### Interface

```nix
# Input: Standard Home Manager module arguments
{ config, lib, pkgs, ... }:

# Output: Home Manager configuration (partial)
{
  home.stateVersion = "24.05";
  
  home.packages = with pkgs; [
    # Core utilities
    coreutils curl wget htop jq
    # File navigation
    tree ripgrep fd
    # Development
    direnv btop ncdu
    # AI tools
    opencode claude-code
    # VCS
    gh
    # Package managers
    nodejs uv
    # Infrastructure
    terraform
    # Secrets
    _1password-cli
  ];
  
  programs = {
    home-manager.enable = true;
    fish = { ... };
    fzf = { ... };
    bat = { ... };
    eza = { ... };
    neovim = { ... };
    bash = { ... };
    zellij = { ... };
    lazygit = { ... };
    tmux = { ... };
    direnv = { ... };
  };
}
```

### Dependencies
- All packages listed must be available in nixpkgs
- Unfree packages (claude-code, terraform, _1password-cli) require allowUnfreePredicate in flake.nix

---

## Module: home/coal.nix

### Purpose
coal's personal Home Manager configuration.

### Interface

```nix
# Input: Standard Home Manager module arguments
{ config, lib, pkgs, ... }:

# Output: Complete Home Manager configuration for coal
{
  imports = [ ./common.nix ];
  
  home.username = "coal";
  home.homeDirectory = "/home/coal";
  
  programs.git = {
    enable = true;
    userName = "coal-bap";
    userEmail = "...";  # coal's email
    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
    };
  };
  
  # coal-specific customizations here
}
```

### Dependencies
- Imports `./common.nix`

---

## Module: home/violino.nix

### Purpose
Violino's personal Home Manager configuration.

### Interface

```nix
# Input: Standard Home Manager module arguments
{ config, lib, pkgs, ... }:

# Output: Complete Home Manager configuration for Violino
{
  imports = [ ./common.nix ];
  
  home.username = "violino";
  home.homeDirectory = "/home/violino";
  
  programs.git = {
    enable = true;
    userName = "Violino";
    userEmail = "violinomaestro@gmail.com";
    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
    };
  };
  
  # Violino-specific customizations here
}
```

### Dependencies
- Imports `./common.nix`

---

## Module: modules/services/code-server.nix

### Purpose
Per-user code-server instances on dedicated ports.

### Current Interface (Single User)
```nix
services.code-server = {
  enable = true;
  host = "127.0.0.1";
  port = 8080;
  auth = "none";
  user = "devuser";  # Single user
};
```

### New Interface (Multi-User)

**Option A: Separate service modules**
```nix
# modules/services/code-server-coal.nix
services.code-server = {
  enable = true;
  host = "127.0.0.1";
  port = 8080;
  auth = "none";
  user = "coal";
};

# modules/services/code-server-violino.nix (optional)
# Similar config on port 8081
```

**Option B: Custom multi-instance module**
```nix
# modules/services/code-server.nix (refactored)
{ config, lib, pkgs, ... }:

let
  users = {
    coal = { port = 8080; enable = true; };
    violino = { port = 8081; enable = true; };  # Optional
  };
in
{
  # Generate systemd services for each user
  systemd.services = lib.mapAttrs' (user: cfg: 
    lib.nameValuePair "code-server-${user}" {
      description = "code-server for ${user}";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        Type = "simple";
        User = user;
        ExecStart = "${pkgs.code-server}/bin/code-server --bind-addr 127.0.0.1:${toString cfg.port} --auth none";
        Restart = "on-failure";
      };
    }
  ) (lib.filterAttrs (_: cfg: cfg.enable) users);
}
```

### Assertions

```nix
assertions = [
  {
    assertion = config.services.tailscale.enable;
    message = "code-server requires Tailscale for secure remote access.";
  }
];
```

### Dependencies
- `pkgs.code-server`
- Tailscale service enabled
- User accounts must exist before code-server services start

---

## Host Configuration Changes

### hosts/devbox/default.nix

```nix
# Current imports
imports = [
  ./hardware-configuration.nix
  ../../modules/core
  ../../modules/networking
  ../../modules/security/ssh.nix
  ../../modules/user        # Multi-user module
  ../../modules/shell
  ../../modules/docker
  ../../modules/services/code-server.nix
];

# No changes needed to imports
# User module handles multi-user internally
```

### hosts/devbox-wsl/default.nix

```nix
# Same imports pattern
# Note: code-server may behave differently in WSL
# Docker may not be available depending on WSL setup
```

---

## Environment Variable Contract

### Build-Time Variables

| Variable | Required For | Description |
|----------|--------------|-------------|
| `SSH_KEY_COAL` | Deploy builds | coal's SSH ed25519 public key |
| `SSH_KEY_VIOLINO` | Deploy builds | Violino's SSH ed25519 public key |

### CI Job Configuration

| Job | SSH Key Vars | Purpose |
|-----|--------------|---------|
| ci-full (release/*) | NOT SET | Build validation only |
| ci-quick (main) | NOT SET | Quick validation |
| publish | NOT SET | FlakeHub publish (safe) |
| deploy (future) | SET | Actual deployment |

### Local Development

```bash
# For local deployment builds
export SSH_KEY_COAL="ssh-ed25519 AAAA..."
export SSH_KEY_VIOLINO="ssh-ed25519 AAAA..."
sudo nixos-rebuild switch --flake .#devbox

# Or use .env file with direnv
# .env (gitignored)
SSH_KEY_COAL="ssh-ed25519 AAAA..."
SSH_KEY_VIOLINO="ssh-ed25519 AAAA..."
```
