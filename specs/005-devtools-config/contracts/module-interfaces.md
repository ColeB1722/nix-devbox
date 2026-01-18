# Module Interfaces: Development Tools and Configuration

**Feature**: 005-devtools-config  
**Date**: 2026-01-18

## Overview

This document defines the interfaces (options, assertions, dependencies) for the new NixOS modules.

---

## Module: modules/shell/default.nix

### Purpose
System-level Fish shell configuration ensuring fish is available and properly set up.

### Options Exposed
None (uses standard NixOS options)

### NixOS Options Used

```nix
programs.fish.enable = true;  # Add fish to /etc/shells
```

### Dependencies
- None

### Assertions
- None (fish availability is implicit)

---

## Module: modules/docker/default.nix

### Purpose
Docker container runtime with proper user permissions.

### Options Exposed
None (uses standard NixOS options)

### NixOS Options Used

```nix
virtualisation.docker = {
  enable = true;
  enableOnBoot = true;
  autoPrune = {
    enable = true;
    dates = "weekly";
  };
};
```

### Dependencies
- modules/user/default.nix (user must be in docker group)

### Assertions

```nix
assertions = [
  {
    assertion = config.users.users.devuser.extraGroups ? "docker" 
                || builtins.elem "docker" config.users.users.devuser.extraGroups;
    message = "User must be in docker group to use Docker without sudo";
  }
];
```

### WSL Handling

```nix
# Skip Docker on WSL (uses Docker Desktop on Windows host)
virtualisation.docker.enable = lib.mkIf (!config.wsl.enable or false) true;
```

---

## Module: modules/services/code-server.nix

### Purpose
Browser-based VS Code for remote development.

### NixOS Options Used

```nix
services.code-server = {
  enable = true;
  host = "127.0.0.1";       # Localhost only
  port = 8080;               # Default port
  auth = "none";             # Tailscale provides auth
  user = "devuser";          # Run as user
  disableTelemetry = true;
  disableUpdateCheck = true;
  extraPackages = with pkgs; [
    git
    nixfmt-rfc-style
    nil                      # Nix LSP
    statix
    deadnix
  ];
};
```

### Dependencies
- modules/networking/tailscale.nix (for secure remote access)
- modules/user/default.nix (user account)

### Firewall Rules
- Port 8080 NOT opened on public firewall
- Accessible only via Tailscale network

### Assertions

```nix
assertions = [
  {
    assertion = config.services.tailscale.enable;
    message = "code-server requires Tailscale for secure remote access";
  }
];
```

---

## Home Manager: home/default.nix Extensions

### New Package Dependencies

```nix
home.packages = with pkgs; [
  # CLI Tools (FR-004, FR-006)
  bat                  # Cat replacement
  eza                  # ls replacement  
  fzf                  # Fuzzy finder (also via programs.fzf)
  
  # Terminal multiplexer (FR-016)
  zellij
  
  # Version control (FR-018, FR-019)
  lazygit
  gh
  
  # Package managers (FR-020, FR-021)
  nodejs               # Includes npm
  uv                   # Python
  
  # Infrastructure (FR-022)
  terraform
  
  # Secrets (FR-023)
  _1password-cli
  
  # AI tools (FR-010, FR-011)
  opencode
  claude-code
];
```

### Program Configurations

#### Fish Shell (FR-001, FR-002, FR-003)

```nix
programs.fish = {
  enable = true;
  
  shellAbbrs = {
    # Git
    g = "git"; ga = "git add"; gaa = "git add --all";
    gc = "git commit"; gcm = "git commit -m";
    gco = "git checkout"; gd = "git diff";
    gst = "git status"; gp = "git push"; gpl = "git pull";
    
    # Nix
    nrs = "sudo nixos-rebuild switch --flake .";
    nrb = "nixos-rebuild build --flake .";
    nfu = "nix flake update";
    
    # Docker
    dc = "docker compose"; dps = "docker ps";
    
    # Misc
    j = "just"; lg = "lazygit";
  };
  
  shellAliases = {
    ls = "eza";
    ll = "eza -l";
    la = "eza -la";
    lt = "eza --tree";
    cat = "bat";
    ".." = "cd ..";
    "..." = "cd ../..";
  };
  
  interactiveShellInit = ''
    set -g fish_greeting  # Disable greeting
  '';
};
```

#### fzf Integration (FR-005)

```nix
programs.fzf = {
  enable = true;
  enableFishIntegration = true;
  defaultCommand = "fd --type f --hidden --exclude .git";
  defaultOptions = [ "--height 40%" "--layout=reverse" "--border" ];
  fileWidgetCommand = "fd --type f --hidden --exclude .git";
  fileWidgetOptions = [ "--preview 'bat --color=always --line-range :50 {}'" ];
  changeDirWidgetCommand = "fd --type d --hidden --exclude .git";
};
```

#### Zellij (FR-016, FR-017)

```nix
programs.zellij = {
  enable = true;
  settings = {
    default_shell = "fish";
    theme = "default";
    pane_frames = true;
  };
};
```

#### Bat (syntax highlighting)

```nix
programs.bat = {
  enable = true;
  config = {
    theme = "TwoDark";
    pager = "less -FR";
  };
};
```

#### Eza (FR-006)

```nix
programs.eza = {
  enable = true;
  enableFishIntegration = true;
  icons = "auto";
  git = true;
};
```

#### Lazygit (FR-018)

```nix
programs.lazygit = {
  enable = true;
  settings = {
    gui.theme = {
      lightTheme = false;
    };
  };
};
```

#### Zed Remote Server (FR-014)

```nix
home.file.".zed_server" = {
  source = "${pkgs.zed-editor.remote_server}/bin";
  recursive = true;
};
```

---

## Unfree Package Allowlist

Required in `home/default.nix` or `flake.nix`:

```nix
nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
  "1password-cli"
  "claude-code"
  "terraform"
];
```

---

## Module Import Order

In `hosts/devbox/default.nix`:

```nix
imports = [
  # Hardware (existing)
  ./hardware-configuration.nix
  
  # Core modules (existing)
  ../../modules/core
  ../../modules/networking
  ../../modules/networking/tailscale.nix
  ../../modules/security/ssh.nix
  ../../modules/user
  
  # New modules
  ../../modules/shell
  ../../modules/docker
  ../../modules/services/code-server.nix
];
```

In `hosts/devbox-wsl/default.nix`:

```nix
imports = [
  # Core modules (existing)
  ../../modules/core
  ../../modules/security/ssh.nix
  ../../modules/user
  
  # New modules (excluding Docker - uses Windows Docker Desktop)
  ../../modules/shell
  # modules/docker - EXCLUDED for WSL
  # modules/services/code-server.nix - optional for WSL
];
```
