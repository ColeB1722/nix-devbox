# Data Model: Extended Development Tools

**Feature**: 008-extended-devtools  
**Date**: 2026-01-25  
**Status**: Complete

## Overview

This document defines the module interfaces, configuration options, and data structures for the Extended Development Tools feature. Since this is a Nix configuration project, "data model" refers to module option schemas and their relationships.

---

## Module Interfaces

### 1. Home Manager CLI Module Extension (`home/modules/cli.nix`)

**Purpose**: Add yazi terminal file manager to existing CLI toolkit.

**New Packages**:
```nix
home.packages = with pkgs; [
  yazi  # Terminal file manager
];
```

**Configuration Options**: None (package-only addition)

**Dependencies**: None

---

### 2. Home Manager Dev Module Extension (`home/modules/dev.nix`)

**Purpose**: Add goose AI agent and Rust toolchain.

**New Packages**:
```nix
home.packages = with pkgs; [
  # AI Coding Tools (existing section)
  goose-cli      # Block's AI agent CLI

  # Rust Toolchain (NEW section)
  rustc          # Rust compiler
  cargo          # Rust package manager
  rustfmt        # Rust formatter
  clippy         # Rust linter
];
```

**Configuration Options**: None (package-only addition)

**Dependencies**: None

---

### 3. NixOS Podman Module (`nixos/podman.nix`) - NEW

**Purpose**: Rootless container runtime as Docker alternative.

**Module Options**:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `devbox.podman.enable` | bool | `true` | Enable Podman container runtime |
| `devbox.podman.dockerCompat` | bool | `true` | Create Docker CLI alias |
| `devbox.podman.enableDns` | bool | `true` | Enable DNS for container networking |

**Interface Definition**:
```nix
{ config, lib, users, ... }:

let
  cfg = config.devbox.podman;
in
{
  options.devbox.podman = {
    enable = lib.mkEnableOption "Podman rootless container runtime";
    
    dockerCompat = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Docker CLI compatibility (creates docker alias)";
    };
    
    enableDns = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable DNS for podman-compose networking";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation = {
      containers.enable = true;
      podman = {
        enable = true;
        dockerCompat = cfg.dockerCompat;
        defaultNetwork.settings.dns_enabled = cfg.enableDns;
      };
    };
    
    # Rootless container support for all users
    users.users = lib.genAttrs users.allUserNames (name: {
      subUidRanges = [{ startUid = 100000; count = 65536; }];
      subGidRanges = [{ startGid = 100000; count = 65536; }];
    });
  };
}
```

**Dependencies**: 
- `users` specialArgs (for user iteration)

**Conflicts With**: 
- `nixos/docker.nix` (do not import both on same host)

**Platform Compatibility**:
- ✅ NixOS bare-metal
- ❌ NixOS WSL (uses Docker Desktop)
- ❌ nix-darwin (not applicable)

---

### 4. NixOS ttyd Module (`nixos/ttyd.nix`) - NEW

**Purpose**: Web-based terminal sharing accessible via Tailscale.

**Module Options**:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `devbox.ttyd.enable` | bool | `false` | Enable ttyd service |
| `devbox.ttyd.port` | int | `7681` | Port for ttyd web server |
| `devbox.ttyd.shell` | string | `"fish"` | Shell to launch |

**Interface Definition**:
```nix
{ config, lib, pkgs, ... }:

let
  cfg = config.devbox.ttyd;
in
{
  options.devbox.ttyd = {
    enable = lib.mkEnableOption "ttyd web terminal sharing";
    
    port = lib.mkOption {
      type = lib.types.port;
      default = 7681;
      description = "Port for ttyd web server";
    };
    
    shell = lib.mkOption {
      type = lib.types.str;
      default = "fish";
      description = "Shell to launch in web terminal";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.ttyd ];
    
    # Firewall: Allow ttyd port only on Tailscale interface
    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ cfg.port ];
    
    # Note: ttyd is typically run ad-hoc by users, not as a persistent service
    # Users run: ttyd -p 7681 fish
    # For persistent service, add systemd unit here
  };
}
```

**Dependencies**: 
- Tailscale must be enabled (for firewall interface)

**Platform Compatibility**:
- ✅ NixOS bare-metal
- ✅ NixOS WSL
- ❌ nix-darwin (different service management)

---

### 5. NixOS Syncthing Module (`nixos/syncthing.nix`) - NEW

**Purpose**: Continuous file synchronization between machines.

**Module Options**:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `devbox.syncthing.enable` | bool | `false` | Enable Syncthing service |
| `devbox.syncthing.user` | string | (first admin) | User to run Syncthing as |
| `devbox.syncthing.dataDir` | path | `/home/<user>/Sync` | Default sync folder |
| `devbox.syncthing.guiPort` | int | `8384` | Web GUI port |

**Interface Definition**:
```nix
{ config, lib, users, ... }:

let
  cfg = config.devbox.syncthing;
  defaultUser = builtins.head users.adminUserNames;
in
{
  options.devbox.syncthing = {
    enable = lib.mkEnableOption "Syncthing file synchronization";
    
    user = lib.mkOption {
      type = lib.types.str;
      default = defaultUser;
      description = "User to run Syncthing as";
    };
    
    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/home/${cfg.user}/Sync";
      description = "Default directory for synced files";
    };
    
    guiPort = lib.mkOption {
      type = lib.types.port;
      default = 8384;
      description = "Port for Syncthing web GUI";
    };
  };

  config = lib.mkIf cfg.enable {
    services.syncthing = {
      enable = true;
      user = cfg.user;
      group = "users";
      dataDir = cfg.dataDir;
      configDir = "/home/${cfg.user}/.config/syncthing";
      guiAddress = "0.0.0.0:${toString cfg.guiPort}";
    };
    
    # Allow GUI access only via Tailscale
    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ cfg.guiPort ];
    
    # Syncthing data transfer ports (22000 TCP, 22000 UDP, 21027 UDP)
    services.syncthing.openDefaultPorts = false;  # We control via Tailscale
    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 22000 ];
    networking.firewall.interfaces.tailscale0.allowedUDPPorts = [ 22000 21027 ];
  };
}
```

**Dependencies**: 
- `users` specialArgs (for default user)
- Tailscale must be enabled (for firewall interface)

**Platform Compatibility**:
- ✅ NixOS bare-metal
- ✅ NixOS WSL
- ⚠️ nix-darwin (different module, future implementation)

---

### 6. NixOS Hyprland Module (`nixos/hyprland.nix`) - NEW (Opt-in)

**Purpose**: Wayland compositor for headed NixOS installations.

**Module Options**:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `devbox.hyprland.enable` | bool | `false` | Enable Hyprland compositor |
| `devbox.hyprland.xwayland` | bool | `true` | Enable XWayland for X11 apps |

**Interface Definition**:
```nix
{ config, lib, ... }:

let
  cfg = config.devbox.hyprland;
in
{
  options.devbox.hyprland = {
    enable = lib.mkEnableOption "Hyprland Wayland compositor (headed systems only)";
    
    xwayland = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable XWayland for X11 application compatibility";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.hyprland = {
      enable = true;
      xwayland.enable = cfg.xwayland;
    };
    
    # Basic dependencies for a usable desktop
    services.xserver.enable = true;
    services.displayManager.sddm.enable = true;
    
    # Note: User-specific Hyprland config should be in Home Manager
    # wayland.windowManager.hyprland.settings = { ... };
  };
}
```

**Dependencies**: None (self-contained)

**Platform Compatibility**:
- ✅ NixOS bare-metal (headed)
- ❌ NixOS bare-metal (headless) - should not enable
- ❌ NixOS WSL - no display
- ❌ nix-darwin - not applicable

**Constitution Note**: This module violates Principle II (Headless-First) by design. It is opt-in and disabled by default. Only enable on explicitly headed configurations.

---

### 7. Darwin Aerospace Module (`darwin/aerospace.nix`) - FUTURE

**Purpose**: Tiling window manager for macOS.

**Status**: Deferred until nix-darwin support is implemented.

**Planned Interface**:
```nix
{ config, lib, pkgs, ... }:

let
  cfg = config.devbox.aerospace;
in
{
  options.devbox.aerospace = {
    enable = lib.mkEnableOption "Aerospace tiling window manager";
    
    startAtLogin = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Start Aerospace at login";
    };
  };

  config = lib.mkIf cfg.enable {
    # Package installation
    home.packages = [ pkgs.aerospace ];
    
    # Configuration file
    xdg.configFile."aerospace/aerospace.toml".text = ''
      start-at-login = ${lib.boolToString cfg.startAtLogin}
      # Default keybindings...
    '';
  };
}
```

**Platform Compatibility**:
- ❌ NixOS (not applicable)
- ✅ nix-darwin only

---

## Entity Relationships

```
┌─────────────────────────────────────────────────────────────────┐
│                     Host Configuration                          │
│  (hosts/devbox/default.nix or hosts/devbox-wsl/default.nix)    │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ imports
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      NixOS Modules                              │
├─────────────────────────────────────────────────────────────────┤
│  nixos/podman.nix      (bare-metal only)                       │
│  nixos/ttyd.nix        (all NixOS)                             │
│  nixos/syncthing.nix   (all NixOS)                             │
│  nixos/hyprland.nix    (headed only, opt-in)                   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ users specialArgs
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      User Data (lib/users.nix)                  │
├─────────────────────────────────────────────────────────────────┤
│  allUserNames: [string]    - For iteration                     │
│  adminUserNames: [string]  - For defaults                      │
└─────────────────────────────────────────────────────────────────┘
                              
┌─────────────────────────────────────────────────────────────────┐
│                    Home Manager Modules                         │
├─────────────────────────────────────────────────────────────────┤
│  home/modules/cli.nix   - yazi (all platforms)                 │
│  home/modules/dev.nix   - goose-cli, rust (all platforms)      │
└─────────────────────────────────────────────────────────────────┘
```

---

## Validation Rules

### Module Enable Assertions

1. **Podman + Docker Conflict**:
   ```nix
   assertions = [{
     assertion = !(config.devbox.podman.enable && config.virtualisation.docker.enable);
     message = "Cannot enable both Podman (with dockerCompat) and Docker. Choose one.";
   }];
   ```

2. **Syncthing User Exists**:
   ```nix
   assertions = [{
     assertion = config.users.users ? ${cfg.user};
     message = "Syncthing user '${cfg.user}' must exist in users configuration.";
   }];
   ```

3. **Hyprland Headless Warning**:
   ```nix
   warnings = lib.optional (cfg.enable && config.wsl.enable)
     "Hyprland is enabled but this appears to be a WSL configuration. Hyprland requires a display.";
   ```

---

## State Transitions

Not applicable - this feature is configuration-only with no runtime state management.

---

## Migration Notes

### From Docker to Podman (bare-metal)

1. Stop Docker containers: `docker stop $(docker ps -q)`
2. Export necessary volumes if needed
3. Remove Docker module import from host configuration
4. Add Podman module import
5. Rebuild: `sudo nixos-rebuild switch`
6. Re-pull images: `podman pull <image>`

### WSL Configuration

WSL configurations should NOT import `nixos/podman.nix`. Continue using Docker Desktop on Windows host.