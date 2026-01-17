# Data Model: Devbox Skeleton

**Feature**: 001-devbox-skeleton
**Date**: 2026-01-17

> Note: For infrastructure-as-code projects, "data model" describes the module structure and configuration entities rather than traditional database entities.

## Module Architecture

### Module Dependency Graph

```text
flake.nix
    │
    └── hosts/devbox/default.nix
            │
            ├── modules/core/default.nix
            │
            ├── modules/networking/default.nix
            │       └── modules/networking/tailscale.nix
            │
            ├── modules/security/ssh.nix
            │
            └── modules/user/default.nix
                    └── home/default.nix (via Home Manager)
```

## Configuration Entities

### 1. Host Configuration

**Location**: `hosts/devbox/default.nix`
**Purpose**: Machine-specific settings that vary per deployment target

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| hostname | string | Yes | Machine network name |
| system | string | Yes | Architecture (x86_64-linux, aarch64-linux) |
| imports | list | Yes | Modules to include |
| hardware-configuration | path | Yes | Generated hardware config |

**Relationships**:
- Imports all enabled modules from `modules/`
- References `hardware-configuration.nix` (generated, gitignored)

### 2. Core Module

**Location**: `modules/core/default.nix`
**Purpose**: Base system settings shared across all hosts

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| time.timeZone | string | "UTC" | System timezone |
| i18n.defaultLocale | string | "en_US.UTF-8" | System locale |
| nix.settings.experimental-features | list | ["nix-command" "flakes"] | Enable flakes |
| nix.settings.auto-optimise-store | bool | true | Deduplicate nix store |
| system.stateVersion | string | "24.05" | NixOS version for stateful compat |

**Dependencies**: None (foundational module)

### 3. Networking Module

**Location**: `modules/networking/default.nix`
**Purpose**: Network and firewall configuration

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| networking.hostName | string | (from host) | System hostname |
| networking.firewall.enable | bool | true | Enable firewall |
| networking.firewall.trustedInterfaces | list | ["tailscale0"] | Interfaces to trust |
| networking.firewall.allowedUDPPorts | list | [41641] | UDP ports to open |
| networking.firewall.allowedTCPPorts | list | [] | TCP ports to open (none by default) |

**Dependencies**: None

### 4. Tailscale Module

**Location**: `modules/networking/tailscale.nix`
**Purpose**: Tailscale VPN service configuration

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| services.tailscale.enable | bool | true | Enable Tailscale |
| services.tailscale.useRoutingFeatures | string | "client" | Routing mode |
| services.tailscale.port | int | 41641 | WireGuard port |

**Dependencies**: `modules/networking/default.nix` (firewall must allow Tailscale)

**State transitions**:
- Stopped → Running (systemd service start)
- Unauthenticated → Authenticated (manual `tailscale up` or authKeyFile)
- Authenticated → Connected (joins tailnet)

### 5. SSH Security Module

**Location**: `modules/security/ssh.nix`
**Purpose**: Hardened SSH server configuration

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| services.openssh.enable | bool | true | Enable SSH server |
| services.openssh.settings.PasswordAuthentication | bool | false | Disable password auth |
| services.openssh.settings.KbdInteractiveAuthentication | bool | false | Disable keyboard-interactive |
| services.openssh.settings.PermitRootLogin | string | "no" | Deny root login |
| services.openssh.settings.LogLevel | string | "VERBOSE" | Verbose logging |

**Dependencies**: `modules/networking/default.nix` (firewall trusts tailscale0 for SSH access)

**Validation rules**:
- PasswordAuthentication MUST be false
- PermitRootLogin MUST be "no"
- At least one authorized key MUST be configured for the primary user

### 6. User Module

**Location**: `modules/user/default.nix`
**Purpose**: User account and Home Manager integration

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| users.users.<name>.isNormalUser | bool | Yes | Create normal user |
| users.users.<name>.extraGroups | list | Yes | Group memberships (wheel for sudo) |
| users.users.<name>.openssh.authorizedKeys.keys | list | Yes | SSH public keys |
| home-manager.users.<name> | module | Yes | Home Manager config |

**Dependencies**: `modules/security/ssh.nix` (SSH must be configured first)

### 7. Home Configuration

**Location**: `home/default.nix`
**Purpose**: User environment managed by Home Manager

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| home.username | string | (required) | Username |
| home.homeDirectory | string | (derived) | Home directory path |
| home.stateVersion | string | "24.05" | HM version for stateful compat |
| programs.git.enable | bool | true | Enable git |
| programs.vim.enable | bool | true | Enable vim (or neovim) |
| home.packages | list | [coreutils, htop, ...] | User packages |

**Dependencies**: `modules/user/default.nix` (user must exist)

## Module Interface Contracts

### Enabling/Disabling Modules

Each module follows the NixOS convention:
- Can be imported without side effects
- Activated via `enable` options or by presence in host imports

### Cross-Module Communication

Modules communicate via standard NixOS options:
- `config.networking.firewall.*` - Firewall settings
- `config.services.tailscale.*` - Tailscale service state
- `config.services.openssh.*` - SSH configuration
- `config.users.users.*` - User accounts

### Validation

Constitution compliance validated at:
1. **Build time**: `nixos-rebuild build` catches syntax/type errors
2. **Evaluation**: Module assertions enforce constraints (e.g., SSH key required)
3. **Runtime**: Services fail-safe (SSH won't start without valid config)
