# Host Configuration - container-host
#
# A lean, secure container management host for multi-tenant Podman workloads.
# Designed for AI agent development containers with strong user isolation.
#
# Key features:
#   - Tailscale SSH with OAuth authentication (no committed SSH keys)
#   - Rootless Podman with per-user isolation
#   - Minimal attack surface (<15 services)
#   - Resource quotas via cgroups v2 and filesystem quotas
#
# IMPORTANT: This is a library module - it does NOT include hardware configuration.
# Consumers must provide their own hardware-configuration.nix.
#
# Constitution alignment:
#   - Principle I: Declarative Configuration (entire host in Nix)
#   - Principle II: Headless-First Design (SSH-only, no GUI)
#   - Principle III: Security by Default (OAuth auth, isolation, minimal services)
#   - Principle IV: Modular and Reusable (importable by consumer flakes)
#   - Principle V: Documentation as Code (inline comments)
#
# Required specialArgs:
#   users - User data attrset (see lib/schema.nix for schema)
#
# Consumer usage:
#   modules = [
#     nix-devbox.hosts.container-host
#     ./hardware/container-host.nix  # Consumer provides hardware config
#   ];
#
# Expected service count: <15 (verify with `systemctl list-units --type=service --state=running | wc -l`)

{ lib, ... }:

{
  imports = [
    # ─────────────────────────────────────────────────────────────────────────
    # NixOS Modules - Minimal Set Only
    # ─────────────────────────────────────────────────────────────────────────
    # This host intentionally imports fewer modules than devbox for reduced
    # attack surface. NO code-server, ttyd, syncthing, or hyprland.

    # Core system settings (locale, timezone, nix)
    ../../nixos/core.nix

    # Package overlays (security-critical packages from unstable)
    ../../nixos/overlays.nix

    # Secrets management (1Password via opnix)
    # Note: Requires opnix.nixosModules.default from flake to be imported
    # by the consumer. See flake.nix nixosConfigurations for example.
    ../../nixos/opnix.nix

    # Security hardening for SSH
    ../../nixos/ssh.nix

    # Firewall configuration
    ../../nixos/firewall.nix

    # Tailscale VPN (required for SSH access)
    ../../nixos/tailscale.nix

    # Tailscale SSH with OAuth (no committed keys)
    ../../nixos/tailscale-ssh.nix

    # Shell configuration (Fish)
    ../../nixos/fish.nix

    # User accounts and Home Manager
    ../../nixos/users.nix

    # Podman with per-user isolation
    ../../nixos/podman-isolation.nix

    # ─────────────────────────────────────────────────────────────────────────
    # NOT IMPORTED (intentionally excluded for minimal attack surface):
    # ─────────────────────────────────────────────────────────────────────────
    # - code-server.nix    (web UI - not needed)
    # - ttyd.nix           (web terminal - not needed)
    # - syncthing.nix      (file sync - not needed)
    # - hyprland.nix       (GUI compositor - violates headless-first)
    # - podman.nix         (replaced by podman-isolation.nix)
    # - docker.nix         (using Podman instead)
  ];

  # ─────────────────────────────────────────────────────────────────────────────
  # Machine Defaults (overridable by consumer)
  # ─────────────────────────────────────────────────────────────────────────────

  networking.hostName = lib.mkDefault "container-host";

  # ─────────────────────────────────────────────────────────────────────────────
  # Devbox Module Defaults
  # ─────────────────────────────────────────────────────────────────────────────

  devbox = {
    # ───────────────────────────────────────────────────────────────────────────
    # Secrets Management (disabled by default)
    # ───────────────────────────────────────────────────────────────────────────
    # Enable 1Password secrets management via opnix.
    # When enabled, you must run `sudo opnix token set` once per machine.
    secrets.enable = lib.mkDefault false;

    # ───────────────────────────────────────────────────────────────────────────
    # Tailscale Configuration
    # ───────────────────────────────────────────────────────────────────────────
    # Tailscale is required for this host (SSH access depends on it)
    tailscale.enable = lib.mkDefault true;

    # Optional: Set authKeyReference to auto-authenticate via 1Password
    # Requires devbox.secrets.enable = true
    # Example: tailscale.authKeyReference = "op://Infrastructure/Tailscale/container-host-auth-key";

    # Enable Tailscale SSH with OAuth authentication
    tailscale.ssh.enable = lib.mkDefault true;

    # Enable Podman with per-user isolation
    podman.isolation.enable = lib.mkDefault true;

    # Enable resource quota enforcement
    podman.isolation.enableQuotas = lib.mkDefault true;
  };

  # ─────────────────────────────────────────────────────────────────────────────
  # Firewall Configuration - Tailscale Only
  # ─────────────────────────────────────────────────────────────────────────────
  # Trust ONLY the Tailscale interface. All other traffic is blocked.

  networking.firewall = {
    enable = true;
    # No ports open to the public internet
    allowedTCPPorts = [ ];
    allowedUDPPorts = [ ];
    # Trust Tailscale interface for SSH and inter-container communication
    trustedInterfaces = [ "tailscale0" ];
  };

  # ─────────────────────────────────────────────────────────────────────────────
  # System State Version
  # ─────────────────────────────────────────────────────────────────────────────

  system.stateVersion = lib.mkDefault "25.05";

  # ─────────────────────────────────────────────────────────────────────────────
  # Note: Hardware Configuration
  # ─────────────────────────────────────────────────────────────────────────────
  # This host definition does NOT include hardware configuration.
  # Consumers MUST provide their own hardware-configuration.nix:
  #
  #   modules = [
  #     nix-devbox.hosts.container-host
  #     ./hardware/container-host.nix  # Your hardware config
  #   ];
  #
  # IMPORTANT: For resource quota storage limits, enable filesystem quotas:
  #   fileSystems."/".options = [ "usrquota" ];
  #
  # Generate hardware config with:
  #   nixos-generate-config --show-hardware-config > hardware/container-host.nix
}
