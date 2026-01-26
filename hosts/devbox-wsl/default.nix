# Host Configuration - devbox-wsl
#
# NixOS host DEFINITION (template) for Windows Subsystem for Linux (WSL2).
# This provides a full NixOS environment accessible via SSH from your tailnet.
#
# IMPORTANT: This is a library module. Consumers must provide NixOS-WSL base module.
#
# Constitution alignment:
#   - Principle IV: Modular and Reusable (importable by consumer flakes)
#   - Principle V: Documentation as Code (inline comments)
#
# Required specialArgs:
#   users - User data attrset (see lib/schema.nix for schema)
#
# Required consumer modules:
#   - nixos-wsl.nixosModules.default (from github:nix-community/NixOS-WSL)
#
# Key differences from bare-metal devbox:
#   - No hardware-configuration.nix (WSL handles hardware)
#   - No bootloader configuration (Windows boots)
#   - Tailscale uses wireguard-go (userspace TUN) instead of kernel WireGuard
#   - Firewall configured for WSL networking
#   - No Docker module (uses Docker Desktop on Windows host)
#
# Consumer usage:
#   modules = [
#     nixos-wsl.nixosModules.default
#     nix-devbox.hosts.devbox-wsl
#   ];

{
  lib,
  pkgs,
  users,
  ...
}:

{
  imports = [
    # ─────────────────────────────────────────────────────────────────────────
    # NixOS Modules (flattened structure)
    # ─────────────────────────────────────────────────────────────────────────

    # Core system settings (locale, timezone, nix settings)
    ../../nixos/core.nix

    # Security hardening for SSH
    ../../nixos/ssh.nix

    # User accounts and Home Manager
    ../../nixos/users.nix

    # Tailscale VPN (runs inside WSL with wireguard-go for TUN support)
    ../../nixos/tailscale.nix

    # Shell configuration (Fish)
    ../../nixos/fish.nix

    # code-server - Browser-based VS Code
    ../../nixos/code-server.nix

    # ttyd - Web terminal sharing (Tailscale-only access)
    ../../nixos/ttyd.nix

    # Syncthing - File synchronization (Tailscale-only access)
    ../../nixos/syncthing.nix

    # Orchestrator - Dev container management (009-devcontainer-orchestrator)
    # Note: WSL uses Podman inside WSL, not Docker Desktop, for orchestrator
    ../../nixos/orchestrator.nix
    ../../nixos/orchestrator-cleanup.nix

    # Podman for container orchestration on WSL
    # Unlike bare-metal, WSL needs explicit Podman setup
    ../../nixos/podman.nix

    # Note: Docker module (../../nixos/docker.nix) is NOT imported for WSL
    # WSL uses Docker Desktop on the Windows host instead
    # See: https://docs.docker.com/desktop/wsl/

    # Note: Firewall module (../../nixos/firewall.nix) is NOT imported for WSL
    # WSL has custom firewall config below
  ];

  # ─────────────────────────────────────────────────────────────────────────────
  # WSL-Specific Configuration
  # ─────────────────────────────────────────────────────────────────────────────

  # Enable WSL integration
  # Note: wsl.defaultUser is set dynamically from the first admin user
  wsl = {
    enable = true;
    defaultUser = lib.mkDefault (
      if users.adminUserNames == [ ] then
        throw "WSL defaultUser requires at least one admin in users.adminUserNames"
      else
        builtins.head users.adminUserNames
    );

    # Start menu launchers for GUI apps (if any)
    startMenuLaunchers = lib.mkDefault false;

    # Use Windows OpenGL drivers for GPU acceleration (optional)
    # Enable if you need GPU support for development
    useWindowsDriver = lib.mkDefault false;

    # WSL interop settings
    interop = {
      # Include Windows PATH in WSL PATH
      # Useful for running Windows commands from WSL
      includePath = lib.mkDefault true;

      # Register binfmt for Windows executables
      register = lib.mkDefault false;
    };

    # Let WSL manage /etc/hosts and /etc/resolv.conf
    # This ensures proper DNS resolution through Windows
    wslConf = {
      network = {
        generateHosts = true;
        generateResolvConf = true;
      };
    };
  };

  # ─────────────────────────────────────────────────────────────────────────────
  # Machine Defaults (overridable by consumer)
  # ─────────────────────────────────────────────────────────────────────────────

  # Machine identity - consumer can override with their preferred hostname
  networking.hostName = lib.mkDefault "devbox-wsl";

  # ─────────────────────────────────────────────────────────────────────────────
  # WSL Networking
  # ─────────────────────────────────────────────────────────────────────────────
  #
  # WSL networking is handled by Windows. Tailscale runs inside WSL,
  # creating a tailscale0 interface via wireguard-go.
  #
  # Firewall is enabled but configured to allow local connections since
  # WSL traffic appears to come from localhost or the WSL virtual network.

  networking.firewall = {
    enable = true;

    # Allow SSH for local WSL connections
    allowedTCPPorts = [ 22 ];

    # Trust Tailscale interface - SSH access is controlled by Tailscale ACLs
    trustedInterfaces = [ "tailscale0" ];
  };

  # ─────────────────────────────────────────────────────────────────────────────
  # Tailscale Configuration (WSL-specific)
  # ─────────────────────────────────────────────────────────────────────────────
  #
  # Tailscale runs inside WSL using wireguard-go to create a tailscale0 TUN
  # interface. This works without kernel WireGuard support.
  #
  # NOTE: Do NOT use `services.tailscale.interfaceName = "userspace-networking"`
  # That forces Tailscale into SOCKS5/HTTP proxy mode which breaks SSH.
  # WSL2 supports /dev/net/tun, so wireguard-go works correctly.
  #
  # After first rebuild, manually authenticate:
  #   sudo tailscale up --authkey=<auth_key>

  # ─────────────────────────────────────────────────────────────────────────────
  # Devbox Module Defaults
  # ─────────────────────────────────────────────────────────────────────────────
  devbox = {
    # Enable Tailscale with WSL-compatible settings
    tailscale = {
      enable = lib.mkDefault true;
      # No routing features needed for basic connectivity
      useRoutingFeatures = lib.mkDefault "none";
    };

    # Enable ttyd for terminal sharing (disabled by default, user enables as needed)
    ttyd.enable = lib.mkDefault false;

    # Enable Syncthing for file sync (disabled by default, user enables as needed)
    syncthing.enable = lib.mkDefault false;

    # Podman for container orchestration (enabled for dev containers on WSL)
    podman.enable = lib.mkDefault true;

    # Orchestrator for dev container management (enabled by default on WSL)
    orchestrator.enable = lib.mkDefault true;
    orchestrator.cleanup.enable = lib.mkDefault true;

    # Note: Hyprland is NOT available on WSL - no display support
  };

  # Use default TUN mode (wireguard-go creates tailscale0 interface)
  # Do NOT set interfaceName = "userspace-networking" - it breaks SSH

  # ─────────────────────────────────────────────────────────────────────────────
  # Disable bare-metal specific features
  # ─────────────────────────────────────────────────────────────────────────────

  # No bootloader in WSL (Windows handles boot)
  boot.loader.grub.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

  # ─────────────────────────────────────────────────────────────────────────────
  # WSL-specific packages
  # ─────────────────────────────────────────────────────────────────────────────

  environment.systemPackages = with pkgs; [
    # WSL utilities
    wslu # WSL utilities (wslview, wslpath, etc.)
  ];

  # NixOS state version - set to 25.05 for fresh WSL installations
  # Do NOT change this after initial deployment
  system.stateVersion = lib.mkDefault "25.05";
}
