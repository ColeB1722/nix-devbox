# Research: Extended Development Tools

**Feature**: 008-extended-devtools  
**Date**: 2026-01-25  
**Status**: Complete

## Overview

This document captures research findings for all tools in the Extended Development Tools feature, resolving technical unknowns and documenting best practices for NixOS/Home Manager integration.

---

## Tool Availability in nixpkgs

| Tool | Package Name | Version | Platform | Notes |
|------|--------------|---------|----------|-------|
| goose | `goose-cli` | 1.19.1 | All | Block's AI agent CLI (not the DB migration tool) |
| cargo/rustc | `rustc`, `cargo` | 1.92.0 | All | Via `rustc` or `rust-bin` overlay |
| yazi | `yazi` | 26.1.22 | All | Terminal file manager |
| Podman | `podman` | Available | Linux | NixOS module: `virtualisation.podman` |
| ttyd | `ttyd` | 1.7.7 | All | Web terminal sharing |
| Syncthing | `syncthing` | Available | All | NixOS module: `services.syncthing` |
| Aerospace | `aerospace` | 0.20.2-Beta | macOS | nix-darwin compatible |
| Hyprland | `hyprland` | Available | Linux | NixOS module: `programs.hyprland` |

**Decision**: All tools are available in nixpkgs. No external overlays or flake inputs required.

---

## Research Tasks

### 1. goose-cli Package Selection

**Unknown**: Multiple "goose" packages exist in nixpkgs.

**Finding**: 
- `goose` (3.26.0) - Database migration tool (NOT what we want)
- `goose-cli` (1.19.1) - Block's open-source AI agent CLI (CORRECT)
- `goose-lang` - Go to Coq converter (NOT what we want)

**Decision**: Use `goose-cli` package.

**Rationale**: `goose-cli` is explicitly described as "Open-source, extensible AI agent that goes beyond code suggestions" which matches the feature requirement.

**Alternatives Considered**: None - clear package distinction in nixpkgs.

---

### 2. Rust Toolchain Installation

**Unknown**: Best approach for Rust toolchain in Nix.

**Finding**: Three approaches available:
1. **nixpkgs `rustc`/`cargo`** - Stable, single version per nixpkgs release
2. **rust-overlay** - Multiple versions, nightly support, extra complexity
3. **fenix** - Similar to rust-overlay, maintained by nix-community

**Decision**: Use nixpkgs `rustc` and `cargo` packages directly.

**Rationale**: 
- Simplest approach aligned with constitution (Principle IV: Modular and Reusable)
- Current need is basic Rust development, not bleeding-edge features
- Avoids adding flake inputs for overlays

**Alternatives Considered**: rust-overlay rejected as overkill for basic cargo availability.

**Implementation**:
```nix
# In home/modules/dev.nix
home.packages = with pkgs; [
  rustc
  cargo
  # Optional: rustfmt, clippy for better DX
  rustfmt
  clippy
];
```

---

### 3. Podman Rootless Configuration

**Unknown**: Best practices for rootless Podman on NixOS.

**Finding**: NixOS provides `virtualisation.podman` module with rootless support.

**Key Configuration** (from NixOS Wiki):
```nix
virtualisation = {
  containers.enable = true;
  podman = {
    enable = true;
    dockerCompat = true;  # Creates 'docker' alias
    defaultNetwork.settings.dns_enabled = true;  # For podman-compose
  };
};

# Rootless requires subuid/subgid ranges
users.users.<USERNAME> = {
  subUidRanges = [{ startUid = 100000; count = 65536; }];
  subGidRanges = [{ startGid = 100000; count = 65536; }];
};
```

**Decision**: Create `nixos/podman.nix` module with rootless configuration.

**Rationale**: 
- Native NixOS module provides tested, declarative configuration
- `dockerCompat = true` provides Docker CLI compatibility
- Rootless is more secure than privileged Docker

**WSL Consideration**: Do NOT import Podman module on WSL - uses Docker Desktop on Windows host.

**Alternatives Considered**: Docker-only rejected as Podman provides better security and is required for feature 009.

---

### 4. ttyd Security Configuration

**Unknown**: How to restrict ttyd to Tailscale network only.

**Finding**: ttyd supports bind address configuration via `-i` flag.

**Approach**: Bind ttyd to Tailscale IP only (not 0.0.0.0).

**Challenge**: Tailscale IP is dynamic. Options:
1. **Bind to localhost + use Tailscale Funnel** - Complex, requires funnel setup
2. **Bind to tailscale0 interface** - ttyd doesn't support interface binding directly
3. **Use systemd socket activation** - Overly complex
4. **Firewall rules** - Block ttyd port except from tailscale0

**Decision**: Bind to 127.0.0.1 and rely on Tailscale SSH/proxy for access, OR use firewall to allow ttyd port only on tailscale0 interface.

**Rationale**: 
- Simplest secure approach
- Users access via `ssh -L` tunnel or Tailscale Serve
- Firewall already trusts tailscale0 interface

**Implementation Pattern**:
```nix
# Option A: User runs ttyd manually with localhost binding
# ttyd -p 7681 -i 127.0.0.1 fish

# Option B: Systemd service with firewall rules
services.ttyd = {
  enable = true;
  port = 7681;
  interface = "127.0.0.1";  # Or use firewall
};

networking.firewall = {
  # Allow ttyd only on Tailscale interface (already trusted)
  interfaces.tailscale0.allowedTCPPorts = [ 7681 ];
};
```

**Note**: ttyd is primarily a CLI tool, not a persistent service. Users invoke it ad-hoc for terminal sharing sessions. System service is optional.

---

### 5. Syncthing User Service Configuration

**Unknown**: System service vs user service for Syncthing.

**Finding**: Two approaches in NixOS:
1. **NixOS service** (`services.syncthing`) - System-level, runs as specified user
2. **Home Manager service** (`services.syncthing`) - User-level systemd user service

**Decision**: Use NixOS `services.syncthing` with per-user configuration.

**Rationale**:
- NixOS service is better tested and documented
- Can specify `user` and `group` to run as specific user
- `configDir` and `dataDir` can be user-specific
- Consistent with existing NixOS module pattern in project

**Implementation Pattern**:
```nix
# In nixos/syncthing.nix
{ config, users, ... }:
{
  services.syncthing = {
    enable = true;
    user = "coal";  # Or iterate over users
    group = "users";
    dataDir = "/home/coal/Sync";
    configDir = "/home/coal/.config/syncthing";
    
    # Bind to Tailscale interface only
    guiAddress = "0.0.0.0:8384";  # Controlled by firewall
  };
  
  # Allow GUI access only via Tailscale
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 8384 ];
}
```

**Alternatives Considered**: Home Manager service rejected as it adds complexity and NixOS service is sufficient.

---

### 6. Aerospace for macOS (nix-darwin)

**Unknown**: Aerospace availability and configuration in nix-darwin.

**Finding**: 
- Package `aerospace` (0.20.2-Beta) is available in nixpkgs
- nix-darwin does not have a dedicated Aerospace module
- Configuration is via `~/.aerospace.toml` (can be managed by Home Manager)

**Decision**: Install via Home Manager package + manage config file.

**Rationale**:
- Simple package installation works
- Config file management via `home.file` or `xdg.configFile`
- No system-level integration needed

**Implementation Pattern**:
```nix
# In home/modules/aerospace.nix (darwin-only)
{ pkgs, lib, ... }:
{
  home.packages = lib.mkIf pkgs.stdenv.isDarwin [ pkgs.aerospace ];
  
  xdg.configFile."aerospace/aerospace.toml".text = ''
    # Aerospace configuration
    start-at-login = true
    # ... keybindings
  '';
}
```

**Note**: Defer to darwin/README.md - nix-darwin is not yet implemented. This is P3 priority.

---

### 7. Hyprland for Headed NixOS

**Unknown**: Hyprland module configuration patterns.

**Finding**: NixOS has native Hyprland support via `programs.hyprland`.

**Key Configuration**:
```nix
programs.hyprland = {
  enable = true;
  xwayland.enable = true;  # For X11 app compatibility
};

# User-specific config via Home Manager
wayland.windowManager.hyprland = {
  enable = true;
  settings = {
    # Keybindings, monitors, etc.
  };
};
```

**Decision**: Create opt-in `nixos/hyprland.nix` module.

**Rationale**:
- Native NixOS module provides proper Wayland session integration
- Must be opt-in (violates headless-first principle by default)
- Home Manager provides user-level customization

**Platform Guard**:
```nix
# In nixos/hyprland.nix
{ config, lib, ... }:
{
  options.devbox.hyprland.enable = lib.mkEnableOption "Hyprland compositor";
  
  config = lib.mkIf config.devbox.hyprland.enable {
    programs.hyprland.enable = true;
    # ... additional config
  };
}
```

**Note**: P4 priority. Not applicable to current headless/WSL configurations.

---

### 8. Docker/Podman Coexistence

**Edge Case**: What happens when both Docker and Podman are installed?

**Finding**: 
- With `dockerCompat = true`, Podman creates a `docker` alias/symlink
- This can conflict if Docker is also installed
- WSL uses Docker Desktop on Windows host (accessed via socket)

**Decision**: 
- Bare-metal NixOS: Use Podman only (remove Docker module import)
- WSL: Continue using Docker Desktop (do not install Podman)

**Rationale**:
- Avoids socket/CLI conflicts
- WSL Docker Desktop integration is well-tested
- Podman provides path to feature 009 on non-WSL

**Migration Path**: Document in quickstart.md that users should choose one runtime.

---

## Module Dependencies

```
home/modules/dev.nix
├── goose-cli (NEW)
├── rustc, cargo, rustfmt, clippy (NEW)
└── (existing tools)

home/modules/cli.nix
└── yazi (NEW)

nixos/podman.nix (NEW)
├── Depends on: users data (for subuid/subgid)
└── Conflicts with: nixos/docker.nix (don't import both)

nixos/ttyd.nix (NEW)
└── Depends on: tailscale for network access

nixos/syncthing.nix (NEW)
├── Depends on: users data (for user/group config)
└── Depends on: tailscale for GUI access

nixos/hyprland.nix (NEW, opt-in)
└── Only for headed NixOS configurations

darwin/aerospace.nix (FUTURE)
└── Only for nix-darwin configurations
```

---

## Open Questions Resolved

| Question | Resolution |
|----------|------------|
| Which goose package? | `goose-cli` (AI agent, not DB migration) |
| Rust toolchain approach? | Direct nixpkgs packages (rustc, cargo) |
| Podman on WSL? | No - use Docker Desktop |
| ttyd security? | Localhost binding + Tailscale tunnel/firewall |
| Syncthing service type? | NixOS service (not Home Manager) |
| Aerospace module? | No module - package + config file |
| Hyprland default? | Opt-in only (headless-first) |
| Docker + Podman? | Choose one per host configuration |

---

## Next Steps

1. **Phase 1**: Create data-model.md with module interfaces
2. **Phase 1**: Create quickstart.md with usage instructions
3. **Phase 1**: Update agent context with new technologies
4. **Phase 2**: Generate implementation tasks (via /speckit.tasks)