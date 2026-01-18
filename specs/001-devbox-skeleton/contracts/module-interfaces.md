# Module Interface Contracts

**Feature**: 001-devbox-skeleton
**Date**: 2026-01-17

> Note: For NixOS infrastructure, "contracts" define module option interfaces rather than API endpoints.

## Module Option Contracts

### Core Module Interface

**Module**: `modules/core/default.nix`
**Imports**: None required

```nix
# No custom options - uses standard NixOS options
# Provides base system defaults
```

**Guarantees**:
- Flakes and nix-command enabled
- Store auto-optimization enabled
- Appropriate stateVersion set

---

### Networking Module Interface

**Module**: `modules/networking/default.nix`
**Imports**: None required

**Provides**:
- Firewall enabled with default-deny
- `tailscale0` trusted by firewall
- UDP 41641 open for Tailscale P2P

**Assertions**:
- `networking.firewall.enable == true`

---

### Tailscale Module Interface

**Module**: `modules/networking/tailscale.nix`
**Imports**: `modules/networking/default.nix` (implicit via host config)

**Provides**:
- `services.tailscale.enable = true`
- Tailscale service configured and started

**Post-deployment requirement**:
- User must run `tailscale up` once to authenticate (or provide authKeyFile)

---

### SSH Security Module Interface

**Module**: `modules/security/ssh.nix`
**Imports**: None required

**Provides**:
- OpenSSH server enabled
- Password authentication disabled
- Root login denied
- Verbose logging enabled

**Assertions**:
- `services.openssh.settings.PasswordAuthentication == false`
- `services.openssh.settings.PermitRootLogin == "no"`

**Requires from consumer**:
- At least one user with `openssh.authorizedKeys.keys` configured

---

### User Module Interface

**Module**: `modules/user/default.nix`
**Imports**: `modules/security/ssh.nix` (for SSH key validation)

**Options exposed**:

| Option | Type | Description |
|--------|------|-------------|
| (hardcoded username) | - | User account configuration |

**Provides**:
- Normal user account
- Wheel group membership (sudo access)
- SSH authorized keys configured
- Home Manager integration

**Assertions**:
- User has at least one SSH authorized key

---

### Home Manager Interface

**Module**: `home/default.nix`
**Imports**: Via `home-manager.users.<name>` in user module

**Provides**:
- Git configured
- Basic editor (vim/neovim)
- Essential CLI utilities

**No custom options** - pure configuration module.

---

## Cross-Module Dependencies

```text
┌──────────────────────────────────────────────────────────────┐
│                        Host Config                            │
│  (hosts/devbox/default.nix)                                  │
└──────────────────────────────────────────────────────────────┘
         │
         ├─────────────────┬─────────────────┬─────────────────┐
         ▼                 ▼                 ▼                 ▼
   ┌──────────┐     ┌──────────────┐   ┌──────────┐     ┌──────────┐
   │   Core   │     │  Networking  │   │ Security │     │   User   │
   │          │     │              │   │   (SSH)  │     │          │
   └──────────┘     └──────────────┘   └──────────┘     └──────────┘
                           │                                  │
                           ▼                                  ▼
                    ┌──────────────┐                   ┌──────────┐
                    │  Tailscale   │                   │   Home   │
                    │              │                   │ Manager  │
                    └──────────────┘                   └──────────┘
```

**Dependency rules**:
1. All modules can be enabled independently (no hard imports)
2. Firewall trusts tailscale0 even if Tailscale module not imported (graceful)
3. SSH module works standalone but requires keys configured elsewhere
4. User module fails assertion (build error) if no valid SSH keys provided

## Flake Contract

**Input requirements**:
```nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  home-manager = {
    url = "github:nix-community/home-manager/release-24.05";
    inputs.nixpkgs.follows = "nixpkgs";
  };
};
```

**Output guarantees**:
```nix
outputs = { self, nixpkgs, home-manager, ... }: {
  nixosConfigurations.devbox = nixpkgs.lib.nixosSystem {
    # Full system configuration
  };
};
```

**Build command**:
```bash
nixos-rebuild build --flake .#devbox
nixos-rebuild switch --flake .#devbox  # Requires sudo on target
```
