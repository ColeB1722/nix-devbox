# NixOS Overlays Module - Security-Critical Package Updates
#
# This module applies overlays to use newer versions of security-critical
# packages from nixpkgs-unstable. This ensures hosts receive timely security
# patches without waiting for the stable channel to update.
#
# Constitution alignment:
#   - Principle III: Security by Default (automatic security updates)
#   - Principle IV: Modular and Reusable (centralized overlay management)
#   - Principle V: Documentation as Code (inline comments)
#
# Required specialArgs:
#   inputs - Flake inputs containing nixpkgs-unstable
#
# Packages overridden:
#   - tailscale: VPN daemon with frequent security updates
#
# Note: Consumers can override with `lib.mkForce` if they need stable versions,
# but this is discouraged for security reasons.

{ inputs, lib, ... }:

{
  nixpkgs.overlays = lib.mkDefault [
    # ─────────────────────────────────────────────────────────────────────────
    # Security-Critical Packages from Unstable
    # ─────────────────────────────────────────────────────────────────────────
    # These packages receive frequent security updates that may not be
    # backported to the stable channel quickly enough.
    (_final: prev: {
      # Tailscale: VPN with WireGuard - frequent security and compatibility updates
      # nixos-25.05 stable often lags behind by 10+ minor versions
      inherit (inputs.nixpkgs-unstable.legacyPackages.${prev.system}) tailscale;
    })
  ];
}
