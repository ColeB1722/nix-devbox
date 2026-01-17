# Research: Devbox Skeleton

**Feature**: 001-devbox-skeleton
**Date**: 2026-01-17

## Flake Structure & Module Organization

### Decision: Hosts-based flake with feature modules

**Rationale**: Separates machine-specific config from reusable modules. Scales cleanly from 1 to N machines by adding `hosts/<hostname>/` directories.

**Alternatives considered**:
- Monolithic configuration.nix: Rejected - violates constitution principle IV (modularity)
- Nix channels: Rejected - flakes provide better pinning and reproducibility

### Recommended Structure

```text
flake.nix                 # Entry point
hosts/
└── devbox/
    ├── default.nix       # Machine config, imports modules
    └── hardware-configuration.nix
modules/
├── core/                 # Base system (locale, timezone, nix settings)
├── networking/           # Firewall, Tailscale
├── security/             # SSH hardening
└── user/                 # User accounts, Home Manager
home/
└── default.nix           # User environment (shell, git, editor)
```

### Home Manager Integration

**Decision**: NixOS module integration (not standalone)

**Rationale**:
- Single `nixos-rebuild switch` updates both system and user config
- Atomic updates - system and home change together
- Simpler for headless servers (no separate `home-manager` command needed)
- `osConfig` available in HM modules to reference system configuration

**Configuration pattern**:
```nix
home-manager.useGlobalPkgs = true;      # Use system nixpkgs
home-manager.useUserPackages = true;    # Install to /etc/profiles
```

## Tailscale Configuration

### Decision: Enable service + trust interface pattern

**Rationale**: `trustedInterfaces = [ "tailscale0" ]` allows all traffic from Tailscale without per-port rules. Simpler and more secure than selective port opening.

**Key settings**:
- `services.tailscale.enable = true`
- `networking.firewall.trustedInterfaces = [ "tailscale0" ]`
- `networking.firewall.allowedUDPPorts = [ 41641 ]` - Enables direct P2P, avoids DERP relay

**Auth key handling**: Use agenix or sops-nix for unattended provisioning. Never commit plaintext auth keys to repo.

## SSH Hardening

### Decision: Key-only auth with maximum hardening

**Rationale**: Password auth is the primary attack vector. Key-only + deny root eliminates brute force entirely.

**Required settings**:
- `PasswordAuthentication = false`
- `KbdInteractiveAuthentication = false`
- `PermitRootLogin = "no"`
- `LogLevel = "VERBOSE"` (for audit trail)

**Key type recommendation**: Ed25519 (modern, fast, secure). RSA 4096 as fallback for legacy compatibility.

**Additional hardening**:
- Manage authorized keys only via NixOS config (not ~/.ssh/authorized_keys)
- Optional: fail2ban or OpenSSH 9.8+ built-in penalties
- NixOS defaults for ciphers/MACs are Mozilla-recommended - no changes needed

## Firewall Configuration

### Decision: Default-deny with Tailscale-only SSH

**Rationale**: Exposing SSH only on Tailscale interface eliminates bot attacks entirely. No port 22 on public interfaces.

**Pattern**:
```nix
networking.firewall = {
  enable = true;
  trustedInterfaces = [ "tailscale0" ];  # All Tailscale traffic allowed
  allowedUDPPorts = [ 41641 ];           # P2P WireGuard
  # NO allowedTCPPorts - nothing exposed publicly
};
```

**Recovery consideration**: Without Tailscale, only local console access works. Recommend disabling Tailscale key expiry for server nodes.

## Secret Management

### Decision: Defer to future feature (auth key placeholder for now)

**Rationale**: Skeleton focuses on structure. Secret management (agenix/sops-nix) is a separate concern that can be added as a module later.

**For initial deployment**: User will manually run `tailscale up` once after first boot. Future enhancement can add auth key file injection.

## Testing Strategy

### Build Verification
- `nix flake check` - Validates flake structure
- `nixos-rebuild build --flake .#devbox` - Full evaluation without deployment

### Integration Testing
- Deploy to throwaway VM (QEMU/VirtualBox)
- Verify SSH via Tailscale IP
- Verify password auth rejected
- Verify firewall blocks public ports

## Summary

| Area | Decision | Key Rationale |
|------|----------|---------------|
| Flake structure | Hosts-based with modules | Scales, modular per constitution |
| Home Manager | NixOS module integration | Single rebuild, atomic updates |
| Tailscale | Trust interface pattern | Simple, secure default |
| SSH | Key-only, no root | Eliminates password attacks |
| Firewall | Tailscale-only exposure | Zero public attack surface |
| Secrets | Deferred (manual tailscale up) | Skeleton scope; add module later |
