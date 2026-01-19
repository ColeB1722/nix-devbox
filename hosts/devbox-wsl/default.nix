# Host Configuration - devbox-wsl
#
# NixOS configuration for running on Windows Subsystem for Linux (WSL2).
# This provides a full NixOS environment accessible via SSH from your tailnet.
#
# Constitution alignment:
#   - Principle IV: Modular and Reusable (shares modules with bare-metal devbox)
#   - Principle V: Documentation as Code (inline comments)
#
# Key differences from bare-metal devbox:
#   - No hardware-configuration.nix (WSL handles hardware)
#   - No bootloader configuration (Windows boots)
#   - Tailscale uses wireguard-go (userspace TUN) instead of kernel WireGuard
#   - Firewall configured for WSL networking
#
# Setup:
#   1. Install NixOS-WSL: https://github.com/nix-community/NixOS-WSL
#   2. Clone this repo inside WSL
#   3. Run: sudo nixos-rebuild switch --flake .#devbox-wsl
#   4. Ensure Tailscale is running on Windows and the machine is in your tailnet
#
# SSH Access:
#   From any machine on your tailnet:
#     ssh coal@<windows-hostname>  # or the Tailscale IP
#
# Feature 006-multi-user-support: Updated for multi-user (coal, violino)

{
  lib,
  pkgs,
  ...
}:

{
  imports = [
    # Core system settings (locale, timezone, nix settings)
    ../../modules/core

    # Security hardening for SSH
    ../../modules/security/ssh.nix

    # User account and Home Manager
    ../../modules/user

    # Tailscale VPN (runs inside WSL with wireguard-go for TUN support)
    ../../modules/networking/tailscale.nix

    # Shell configuration (Fish) - Feature 005
    ../../modules/shell

    # Note: Docker module (../../modules/docker) is NOT imported for WSL
    # WSL uses Docker Desktop on the Windows host instead
    # See: https://docs.docker.com/desktop/wsl/
  ];

  # ─────────────────────────────────────────────────────────────────────────────
  # WSL-Specific Configuration
  # ─────────────────────────────────────────────────────────────────────────────

  # Enable WSL integration
  wsl = {
    enable = true;
    defaultUser = "coal"; # Primary admin user (Feature 006)

    # Start menu launchers for GUI apps (if any)
    startMenuLaunchers = false;

    # Use Windows OpenGL drivers for GPU acceleration (optional)
    # Enable if you need GPU support for development
    useWindowsDriver = false;

    # WSL interop settings
    interop = {
      # Include Windows PATH in WSL PATH
      # Useful for running Windows commands from WSL
      includePath = true;

      # Register binfmt for Windows executables
      register = false;
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

  # Machine identity
  networking.hostName = "devbox-wsl";

  # ─────────────────────────────────────────────────────────────────────────────
  # WSL Networking
  # ─────────────────────────────────────────────────────────────────────────────
  #
  # WSL networking is handled by Windows. Tailscale runs on the Windows host,
  # not inside WSL. SSH connections come through Windows networking.
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
  #   sudo tailscale up --authkey=<shared_auth_key>
  #
  # Get the auth key from homelab-iac:
  #   cd ~/repos/homelab-iac && just output tailscale shared_auth_key

  # Enable Tailscale with WSL-compatible settings
  devbox.tailscale = {
    enable = true;
    # No routing features needed for basic connectivity
    useRoutingFeatures = "none";
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
  system.stateVersion = "25.05";
}
