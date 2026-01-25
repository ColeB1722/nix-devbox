# NixOS Core Module - Base System Configuration
#
# Foundational system settings shared across all NixOS hosts.
# Enables Nix flakes, sets locale/timezone defaults, and configures
# the Nix store for optimization.
#
# Constitution alignment:
#   - Principle I: Declarative Configuration (all settings in Nix)
#   - Principle V: Documentation as Code (inline comments)

{ lib, ... }:

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

  # Automatic garbage collection to prevent disk fill-up
  # Runs weekly, removes generations older than 30 days
  # Consumers can override or disable via lib.mkForce
  nix.gc = {
    automatic = lib.mkDefault true;
    dates = lib.mkDefault "weekly";
    options = lib.mkDefault "--delete-older-than 30d";
  };

  # Note: Unfree packages are controlled via allowUnfreePredicate in the
  # consumer's flake.nix (or mkNixpkgsConfig in this repo's flake.nix).
  # This ensures explicit allowlisting rather than blanket allowUnfree.

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

  # Note: system.stateVersion is NOT set here - it should be set in:
  # - Hardware configuration (for bare-metal/VM)
  # - Host configuration (for WSL or other specialized hosts)
  # This ensures each deployment uses the appropriate version for its initial install.
}
