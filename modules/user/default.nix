# User Module - User Account and Home Manager Integration
#
# This module creates the primary user account and integrates Home Manager
# for user environment management. SSH keys are configured here.
#
# Constitution alignment:
#   - Principle I: Declarative Configuration (user managed in Nix)
#   - Principle III: Security by Default (SSH keys managed declaratively)
#   - Principle V: Documentation as Code (inline comments)
#
# IMPORTANT: You MUST replace the placeholder SSH key with your actual public key
# before deploying. The system will not be accessible without a valid SSH key.

{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  # Primary username - change this to your preferred username
  username = "devuser";

  # Get the user's SSH keys for assertion checking
  userKeys = config.users.users.${username}.openssh.authorizedKeys.keys;
in
{
  # Security assertion: User MUST have at least one SSH key configured
  # Since password auth is disabled, no SSH key = no access
  assertions = [
    {
      assertion = (builtins.length userKeys) > 0;
      message = ''
        SECURITY WARNING: No SSH keys configured for user '${username}'.
        With password authentication disabled, you will be locked out!
        Add your public key to users.users.${username}.openssh.authorizedKeys.keys
      '';
    }
  ];

  # Create the primary user account
  users.users.${username} = {
    isNormalUser = true;
    description = "Development User";

    # Group memberships:
    # - wheel: sudo access for system administration
    # - networkmanager: network configuration (if needed)
    extraGroups = [
      "wheel"
      "networkmanager"
    ];

    # SSH authorized keys - REPLACE WITH YOUR ACTUAL PUBLIC KEY
    # Generate with: ssh-keygen -t ed25519 -C "devbox"
    # Then paste the contents of ~/.ssh/id_ed25519.pub here
    openssh.authorizedKeys.keys = [
      # TODO: Replace this placeholder with your actual SSH public key
      # Example: "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA... your-email@example.com"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPlaceholderKeyReplaceWithYourActualPublicKey devbox-placeholder"
    ];

    # Default shell
    shell = pkgs.bash;
  };

  # Enable sudo for wheel group (passwordless for convenience in dev environment)
  # In production, consider removing NOPASSWD
  security.sudo.wheelNeedsPassword = false;

  # Home Manager configuration for the user
  home-manager.users.${username} = import ../../home;
}
