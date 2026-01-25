# NixOS Modules Interface Contract

**Feature**: 007-library-flake-architecture  
**Date**: 2025-01-22  
**Status**: Complete

## Overview

This document defines the interface contract for NixOS modules exported by the nix-devbox library flake. Consumers import these modules and provide required data via `specialArgs`.

## Module Exports

```nix
nixosModules = {
  # Individual modules
  core        = import ./nixos/core.nix;
  ssh         = import ./nixos/ssh.nix;
  firewall    = import ./nixos/firewall.nix;
  tailscale   = import ./nixos/tailscale.nix;
  docker      = import ./nixos/docker.nix;
  fish        = import ./nixos/fish.nix;
  users       = import ./nixos/users.nix;
  code-server = import ./nixos/code-server.nix;
  
  # All modules combined
  default = { imports = [ /* all above */ ]; };
};
```

## Module Interface Specifications

### Common Requirements

All modules that create user-specific resources require the `users` argument from `specialArgs`:

```nix
{ config, lib, pkgs, users, ... }:
```

### core.nix

**Purpose**: Base system configuration (nix settings, locale, timezone, bootloader)

**Required Args**: None (standalone module)

**Provides**:
- Nix flakes enabled
- Locale: en_US.UTF-8
- Timezone: UTC (overridable via `lib.mkDefault`)
- Bootloader configuration

**Consumer Overrides**:
```nix
time.timeZone = "America/New_York";  # Override default UTC
```

---

### ssh.nix

**Purpose**: Hardened SSH server configuration

**Required Args**: None (uses system config for authorized keys)

**Provides**:
- SSH server enabled
- Password authentication: DISABLED (security assertion)
- Root login: DISABLED (security assertion)
- Key-based authentication only

**Security Assertions** (non-overridable):
```nix
services.openssh.settings.PasswordAuthentication = false;
services.openssh.settings.PermitRootLogin = "no";
```

**Consumer Interface**: SSH keys are configured via `users.nix` → `openssh.authorizedKeys.keys`

---

### firewall.nix

**Purpose**: Default-deny firewall with Tailscale trust

**Required Args**: None

**Provides**:
- Firewall enabled (security assertion)
- Tailscale interface trusted
- SSH port allowed
- code-server ports allowed (from `users.codeServerPorts`)

**Security Assertions** (non-overridable):
```nix
networking.firewall.enable = true;
```

**Consumer Overrides**:
```nix
networking.firewall.allowedTCPPorts = [ 443 ];  # Add extra ports
```

---

### tailscale.nix

**Purpose**: Tailscale VPN service

**Required Args**: None

**Provides**:
- Tailscale service enabled
- Option `devbox.tailscale.enable` for easy toggling

**Consumer Interface**:
```nix
devbox.tailscale.enable = true;  # Default
devbox.tailscale.enable = false; # Disable for local-only setups
```

---

### docker.nix

**Purpose**: Docker daemon with auto-prune

**Required Args**: `users` (for group membership)

**Provides**:
- Docker daemon enabled
- Weekly auto-prune
- Users with `isAdmin = true` or explicit docker group get docker access

**Consumer Interface**: Controlled via user's `extraGroups` or automatic for admins

---

### fish.nix

**Purpose**: Fish shell system enablement

**Required Args**: None

**Provides**:
- Fish shell available system-wide
- Sets fish as default shell for users (via users.nix)

---

### users.nix

**Purpose**: Create user accounts from consumer-provided data

**Required Args**: `users` (REQUIRED)

**Input Schema**:
```nix
users = {
  <username> = {
    name = "<username>";
    uid = <integer>;
    description = "<string>";
    email = "<email>";
    gitUser = "<github-username>";
    isAdmin = <boolean>;
    sshKeys = [ "<pubkey>" ... ];
    extraGroups = [ "<group>" ... ];  # optional
  };
  allUserNames = [ ... ];
  adminUserNames = [ ... ];
};
```

**Provides**:
- System user accounts for each user in `users`
- Group memberships:
  - `wheel` if `isAdmin = true`
  - `docker` for all users
  - Additional groups from `extraGroups`
- SSH authorized keys from `sshKeys`
- Fish as default shell
- Home Manager integration (forwards `users` to HM modules)

**Security Assertions**:
- Non-admin users MUST NOT be in wheel group
- All users MUST have at least one SSH key

---

### code-server.nix

**Purpose**: Per-user VS Code in browser

**Required Args**: `users` (REQUIRED)

**Input Schema**:
```nix
users = {
  allUserNames = [ "user1" "user2" ];
  codeServerPorts = {
    user1 = 8080;
    user2 = 8081;
  };
};
```

**Provides**:
- code-server service for each user in `allUserNames`
- Port assignment from `codeServerPorts`
- Firewall rules for each port

**Consumer Interface**: Port assignments via `codeServerPorts` in users.nix

---

## Host Definitions

### hosts/devbox

**Purpose**: Bare-metal/VM devbox host definition

**Required Args**: `users` (passed to imported modules)

**Required Consumer Modules**:
- Hardware configuration (consumer provides `./hardware/devbox.nix`)

**Imports**:
```nix
[
  core ssh firewall tailscale docker fish users code-server
]
```

**Defaults** (overridable):
```nix
networking.hostName = lib.mkDefault "devbox";
devbox.tailscale.enable = lib.mkDefault true;
```

---

### hosts/devbox-wsl

**Purpose**: WSL2 host definition

**Required Args**: `users` (passed to imported modules)

**Required Consumer Modules**:
- NixOS-WSL base module (consumer includes `nixos-wsl.nixosModules.default`)

**Imports**:
```nix
[
  core ssh firewall tailscale fish users code-server
  # NOTE: docker.nix NOT included (uses Docker Desktop on Windows)
]
```

**Defaults** (overridable):
```nix
networking.hostName = lib.mkDefault "devbox-wsl";
wsl.enable = true;
```

---

## Consumer Usage Example

```nix
# Consumer's flake.nix
{
  inputs.nix-devbox.url = "https://flakehub.com/f/coal-bap/nix-devbox/*";
  
  outputs = { nix-devbox, nixpkgs, ... }:
  let
    users = import ./users.nix;
  in {
    nixosConfigurations.mybox = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit users; };
      modules = [
        # Option 1: All modules at once
        nix-devbox.nixosModules.default
        
        # Option 2: Selective modules
        # nix-devbox.nixosModules.core
        # nix-devbox.nixosModules.ssh
        # nix-devbox.nixosModules.users
        
        # Consumer's hardware
        ./hardware/mybox.nix
      ];
    };
  };
}
```

## Validation

Modules validate their inputs at evaluation time. Invalid data produces clear error messages:

```
error: User 'alice' is missing required fields: sshKeys
error: User 'bob' uid must be 1000-65533 (got 500)
```

See [data-model.md](../data-model.md) for complete validation rules.