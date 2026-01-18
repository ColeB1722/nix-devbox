# Core Module - Base System Configuration
#
# This module provides foundational system settings shared across all hosts.
# It enables Nix flakes, sets locale/timezone defaults, and configures the
# Nix store for optimization.
#
# Constitution alignment:
#   - Principle I: Declarative Configuration (all settings in Nix)
#   - Principle V: Documentation as Code (inline comments)

{
  config,
  lib,
  pkgs,
  ...
}:

{
  # Enable experimental features for flakes support
  # Required for flake-based configuration management
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];

    # Automatically deduplicate identical files in the Nix store
    # Saves disk space without affecting functionality
    auto-optimise-store = true;
  };

  # Allow unfree packages (some common tools require this)
  nixpkgs.config.allowUnfree = true;

  # Timezone configuration
  # Default to UTC for server consistency; override in host config if needed
  time.timeZone = lib.mkDefault "UTC";

  # Locale configuration
  # US English UTF-8 as default; sufficient for CLI-only usage
  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";

  # Console configuration for headless operation
  console = {
    font = "Lat2-Terminus16";
    keyMap = lib.mkDefault "us";
  };

  # Boot loader configuration
  # GRUB for BIOS/UEFI compatibility; adjust in host config if needed
  boot.loader.grub = {
    enable = lib.mkDefault true;
    device = lib.mkDefault "nodev"; # Override in hardware-configuration.nix
    efiSupport = lib.mkDefault true;
  };
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;

  # NixOS state version
  # This determines which NixOS defaults are used for stateful data
  # Should match the NixOS version used for initial installation
  system.stateVersion = "24.05";
}
