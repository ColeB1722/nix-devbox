# Host Configuration - devbox
#
# This is the machine-specific configuration for the devbox.
# It imports all reusable modules and sets machine-specific overrides.
#
# Constitution alignment:
#   - Principle IV: Modular and Reusable (imports composable modules)
#   - Principle V: Documentation as Code (inline comments)
#
# To deploy:
#   1. Edit hardware-configuration.nix.example with your disk UUIDs and hardware
#      (or generate with: nixos-generate-config --show-hardware-config)
#   2. Update the SSH key in modules/user/default.nix
#   3. Run: sudo nixos-rebuild switch --flake .#devbox

{
  _config,
  _lib,
  pkgs,
  _inputs,
  ...
}:

{
  imports = [
    # Hardware configuration (template - customize for your machine)
    # To use: copy to hardware-configuration.nix.local (gitignored) and import that instead
    # Or edit this file directly with your hardware config
    ./hardware-configuration.nix.example

    # Core system settings
    ../../modules/core

    # Networking and firewall
    ../../modules/networking
    ../../modules/networking/tailscale.nix

    # Security hardening
    ../../modules/security/ssh.nix

    # User account and Home Manager
    ../../modules/user
  ];

  # Machine identity
  networking.hostName = "devbox";

  # Enable Tailscale VPN (can be disabled by setting to false)
  devbox.tailscale.enable = true;

  # Override timezone if needed (default is UTC from core module)
  # time.timeZone = "America/New_York";

  # Machine-specific packages (beyond what modules provide)
  environment.systemPackages = with pkgs; [
    # Add machine-specific packages here
  ];
}
