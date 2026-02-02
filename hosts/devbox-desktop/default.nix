# Host Configuration - devbox-desktop
#
# This is the host DEFINITION (template) for headful NixOS desktop machines.
# It imports all reusable modules and sets machine-specific defaults.
#
# IMPORTANT: This is a library module - it does NOT include hardware configuration.
# Consumers must provide their own hardware-configuration.nix.
#
# Features:
#   - Hyprland Wayland compositor
#   - Full CLI development toolkit via Home Manager
#   - GPU acceleration (AMD/Intel preferred, NVIDIA requires extra config)
#
# Consumer usage:
#   modules = [
#     nix-devbox.hosts.devbox-desktop
#     ./hardware/desktop.nix  # Consumer provides hardware config
#   ];
#
# Direct usage (with hardware config):
#   sudo nixos-rebuild switch --flake .#devbox-desktop
#
# Constitution alignment:
#   - Principle I: Declarative Configuration (entire desktop in Nix)
#   - Principle II: Headless-First Design - ⚠️ VIOLATION (justified for workstation)
#   - Principle IV: Modular and Reusable (importable by consumer flakes)
#   - Principle V: Documentation as Code (inline comments)
#
# CONSTITUTION VIOLATION JUSTIFICATION (Principle II):
#   This is a headful desktop configuration, which violates headless-first.
#   Justified because:
#   - It's a dedicated workstation host (not a server)
#   - It's opt-in (separate host config from headless devbox)
#   - Local development sometimes requires GUI (testing, design tools)

{
  lib,
  pkgs,
  ...
}:

{
  imports = [
    # NOTE: Hardware configuration is NOT imported here.
    # Consumers must provide their own hardware-configuration.nix
    # or the flake provides ./examples/hardware-example.nix for CI.

    # Core NixOS modules
    ../../nixos/core.nix

    # Package overlays (security-critical packages from unstable)
    ../../nixos/overlays.nix

    # Secrets management (1Password via opnix)
    # Note: Requires opnix.nixosModules.default from flake to be imported
    # by the consumer. See flake.nix nixosConfigurations for example.
    ../../nixos/opnix.nix
    ../../nixos/ssh.nix
    ../../nixos/firewall.nix
    ../../nixos/tailscale.nix
    ../../nixos/fish.nix
    ../../nixos/users.nix

    # Hyprland compositor (headful only)
    ../../nixos/hyprland.nix

    # Optional services (uncomment as needed)
    # ../../nixos/syncthing.nix
  ];

  # ─────────────────────────────────────────────────────────────────────────────
  # System Identification
  # ─────────────────────────────────────────────────────────────────────────────

  networking = {
    hostName = lib.mkDefault "devbox-desktop";
    # NetworkManager for easy network configuration
    networkmanager.enable = true;
  };

  # ─────────────────────────────────────────────────────────────────────────────
  # Secrets Management (disabled by default)
  # ─────────────────────────────────────────────────────────────────────────────
  # Enable 1Password secrets management via opnix.
  # When enabled, you must run `sudo opnix token set` once per machine.
  devbox.secrets.enable = lib.mkDefault false;

  # Optional: Set authKeyReference to auto-authenticate Tailscale via 1Password
  # Requires devbox.secrets.enable = true
  # Example: devbox.tailscale.authKeyReference = "op://Infrastructure/Tailscale/desktop-auth-key";

  # ─────────────────────────────────────────────────────────────────────────────
  # Hyprland Configuration
  # ─────────────────────────────────────────────────────────────────────────────

  devbox.hyprland = {
    enable = true;
    xwayland = true; # Enable X11 compatibility for legacy apps
  };

  # ─────────────────────────────────────────────────────────────────────────────
  # Hardware Configuration (consolidated)
  # ─────────────────────────────────────────────────────────────────────────────

  hardware = {
    # ─── Graphics ───
    # AMD/Intel GPUs work out of the box. For NVIDIA, see notes below.
    graphics = {
      enable = true;
      # Enable 32-bit support for Steam, Wine, etc.
      enable32Bit = true;
    };

    # ─── Bluetooth ───
    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };

    # ─── NVIDIA Configuration (Uncomment if using NVIDIA GPU) ───
    # Note: NVIDIA + Wayland can be problematic. Consider AMD/Intel for best experience.
    # If uncommenting, add 'config' to the function arguments above: { config, lib, pkgs, ... }
    # nvidia = {
    #   modesetting.enable = true;
    #   powerManagement.enable = true;
    #   open = false;  # Use proprietary driver (more stable)
    #   nvidiaSettings = true;
    #   package = config.boot.kernelPackages.nvidiaPackages.stable;
    # };
  };

  # ─────────────────────────────────────────────────────────────────────────────
  # Services Configuration (consolidated)
  # ─────────────────────────────────────────────────────────────────────────────

  services = {
    # Disable PulseAudio (we use PipeWire's pulse emulation)
    pulseaudio.enable = false;

    # ─── Audio (PipeWire) ───
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
      wireplumber.enable = true;
    };

    # ─── Desktop Services ───
    dbus.enable = true;
    gvfs.enable = true; # File manager integration (trash, network mounts)
    tumbler.enable = true; # Thumbnail service for file managers
    blueman.enable = true; # Bluetooth manager

    # ─── Power Management ───
    tlp.enable = lib.mkDefault false; # Enable for laptops
    upower.enable = true;

    # ─── GNOME Keyring ───
    gnome.gnome-keyring.enable = true;

    # ─── NVIDIA (uncomment if using NVIDIA GPU) ───
    # xserver.videoDrivers = [ "nvidia" ];
  };

  # ─────────────────────────────────────────────────────────────────────────────
  # Security Configuration
  # ─────────────────────────────────────────────────────────────────────────────

  security = {
    # Enable rtkit for realtime audio priorities
    rtkit.enable = true;

    # Polkit for privilege escalation dialogs
    polkit.enable = true;
  };

  # ─────────────────────────────────────────────────────────────────────────────
  # XDG Portal Configuration
  # ─────────────────────────────────────────────────────────────────────────────

  xdg.portal = {
    enable = true;
    wlr.enable = false;
    extraPortals = [
      pkgs.xdg-desktop-portal-hyprland
      pkgs.xdg-desktop-portal-gtk
    ];
    config.common.default = [
      "hyprland"
      "gtk"
    ];
  };

  # ─────────────────────────────────────────────────────────────────────────────
  # Fonts
  # ─────────────────────────────────────────────────────────────────────────────

  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      nerd-fonts.fira-code
      nerd-fonts.jetbrains-mono
      nerd-fonts.hack
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-emoji
      liberation_ttf
    ];

    fontconfig = {
      defaultFonts = {
        monospace = [ "JetBrainsMono Nerd Font" ];
        sansSerif = [ "Noto Sans" ];
        serif = [ "Noto Serif" ];
      };
    };
  };

  # ─────────────────────────────────────────────────────────────────────────────
  # Desktop Applications
  # ─────────────────────────────────────────────────────────────────────────────

  environment.systemPackages = with pkgs; [
    # Terminal emulators
    kitty
    alacritty

    # Application launcher
    wofi
    rofi-wayland

    # Status bar
    waybar

    # Notification daemon
    mako

    # Screenshot tools
    grim
    slurp

    # Clipboard
    wl-clipboard

    # File manager
    nautilus

    # Image viewer
    imv

    # PDF viewer
    zathura

    # Browser
    firefox

    # Wayland utilities
    wlr-randr
    wdisplays
    kanshi # Auto-configure displays

    # Screen locker
    swaylock
    swayidle
  ];

  # ─────────────────────────────────────────────────────────────────────────────
  # Platform Configuration
  # ─────────────────────────────────────────────────────────────────────────────

  nixpkgs.config.allowUnfree = true;

  system.stateVersion = "25.05";
}
