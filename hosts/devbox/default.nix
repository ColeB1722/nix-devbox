# Host Configuration - devbox
#
# This is the host DEFINITION (template) for bare-metal/VM devbox machines.
# It imports all reusable modules and sets machine-specific defaults.
#
# IMPORTANT: This is a library module - it does NOT include hardware configuration.
# Consumers must provide their own hardware-configuration.nix.
#
# Constitution alignment:
#   - Principle IV: Modular and Reusable (importable by consumer flakes)
#   - Principle V: Documentation as Code (inline comments)
#
# Required specialArgs:
#   users - User data attrset (see lib/schema.nix for schema)
#
# Consumer usage:
#   modules = [
#     nix-devbox.hosts.devbox
#     ./hardware/devbox.nix  # Consumer provides hardware config
#   ];

{ lib, ... }:

{
  imports = [
    # ─────────────────────────────────────────────────────────────────────────
    # NixOS Modules (flattened structure)
    # ─────────────────────────────────────────────────────────────────────────

    # Core system settings
    ../../nixos/core.nix

    # Networking and firewall
    ../../nixos/firewall.nix
    ../../nixos/tailscale.nix

    # Security hardening
    ../../nixos/ssh.nix

    # User accounts and Home Manager
    ../../nixos/users.nix

    # Shell configuration (Fish)
    ../../nixos/fish.nix

    # Docker container runtime
    # Note: NOT included in WSL config (uses Docker Desktop on Windows host)
    ../../nixos/docker.nix

    # code-server - Browser-based VS Code
    ../../nixos/code-server.nix
  ];

  # ─────────────────────────────────────────────────────────────────────────────
  # Machine Defaults (overridable by consumer)
  # ─────────────────────────────────────────────────────────────────────────────

  # Machine identity - consumer can override with their preferred hostname
  networking.hostName = lib.mkDefault "devbox";

  # Enable Tailscale VPN by default (can be disabled by consumer)
  devbox.tailscale.enable = lib.mkDefault true;

  # Timezone default (consumer can override)
  # time.timeZone is already set to UTC in core.nix with mkDefault

  # ─────────────────────────────────────────────────────────────────────────────
  # Note: Hardware Configuration
  # ─────────────────────────────────────────────────────────────────────────────
  # This host definition does NOT include hardware configuration.
  # Consumers MUST provide their own hardware-configuration.nix:
  #
  #   modules = [
  #     nix-devbox.hosts.devbox
  #     ./hardware/devbox.nix  # Your hardware config
  #   ];
  #
  # Generate hardware config with:
  #   nixos-generate-config --show-hardware-config > hardware/devbox.nix
}
