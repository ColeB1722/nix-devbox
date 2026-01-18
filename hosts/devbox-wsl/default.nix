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
#   - No Tailscale service (runs on Windows host instead)
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
#     ssh devuser@<windows-hostname>  # or the Tailscale IP

{
  _config,
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
  ];

  # ─────────────────────────────────────────────────────────────────────────────
  # WSL-Specific Configuration
  # ─────────────────────────────────────────────────────────────────────────────

  # Enable WSL integration
  wsl = {
    enable = true;
    defaultUser = "devuser";

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

    # Allow SSH from anywhere since Windows/Tailscale handles external filtering
    # WSL is essentially "behind" the Windows firewall + Tailscale ACLs
    allowedTCPPorts = [ 22 ];

    # No Tailscale interface in WSL - it runs on Windows
    trustedInterfaces = [ ];
  };

  # ─────────────────────────────────────────────────────────────────────────────
  # Disable bare-metal specific features
  # ─────────────────────────────────────────────────────────────────────────────

  # No bootloader in WSL (Windows handles boot)
  boot.loader.grub.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

  # Tailscale runs on Windows, not in WSL
  # The devbox.tailscale option doesn't exist in WSL config (module not imported)
  # If you need Tailscale in WSL directly, uncomment the tailscale import above
  # and use userspace networking: tailscale up --netfilter-mode=off

  # ─────────────────────────────────────────────────────────────────────────────
  # WSL-specific packages
  # ─────────────────────────────────────────────────────────────────────────────

  environment.systemPackages = with pkgs; [
    # WSL utilities
    wslu # WSL utilities (wslview, wslpath, etc.)
  ];

  # NixOS state version
  system.stateVersion = "24.05";
}
