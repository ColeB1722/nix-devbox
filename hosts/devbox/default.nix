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
#   1. Copy hardware-configuration.nix.example to hardware-configuration.nix
#   2. Generate actual hardware config: nixos-generate-config --show-hardware-config
#   3. Update the SSH key in modules/user/default.nix
#   4. Run: sudo nixos-rebuild switch --flake .#devbox

{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    # Hardware configuration (generated per-machine, gitignored)
    ./hardware-configuration.nix

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
