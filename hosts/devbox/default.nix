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

    # Podman container runtime (replaces Docker for bare-metal)
    # Note: NOT included in WSL config (uses Docker Desktop on Windows host)
    # Note: Conflicts with docker.nix when dockerCompat is enabled
    ../../nixos/podman.nix

    # ttyd - Web terminal sharing (Tailscale-only access)
    ../../nixos/ttyd.nix

    # Syncthing - File synchronization (Tailscale-only access)
    ../../nixos/syncthing.nix

    # Hyprland - Wayland compositor (opt-in, headed systems only)
    ../../nixos/hyprland.nix

    # code-server - Browser-based VS Code
    ../../nixos/code-server.nix
  ];

  # ─────────────────────────────────────────────────────────────────────────────
  # Machine Defaults (overridable by consumer)
  # ─────────────────────────────────────────────────────────────────────────────

  # Machine identity - consumer can override with their preferred hostname
  networking.hostName = lib.mkDefault "devbox";

  # ─────────────────────────────────────────────────────────────────────────────
  # Devbox Module Defaults
  # ─────────────────────────────────────────────────────────────────────────────
  devbox = {
    # Enable Tailscale VPN by default (can be disabled by consumer)
    tailscale.enable = lib.mkDefault true;

    # Enable Podman container runtime by default (bare-metal only)
    podman.enable = lib.mkDefault true;

    # Enable ttyd for terminal sharing (disabled by default, user enables as needed)
    ttyd.enable = lib.mkDefault false;

    # Enable Syncthing for file sync (disabled by default, user enables as needed)
    syncthing.enable = lib.mkDefault false;

    # Hyprland is opt-in and disabled by default (violates headless-first principle)
    hyprland.enable = lib.mkDefault false;
  };

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
