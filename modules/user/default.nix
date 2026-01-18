# User Module - Multi-User Account and Home Manager Integration
#
# This module creates user accounts for coal (primary admin) and violino (secondary user)
# and integrates Home Manager for per-user environment management.
#
# SSH public keys are hardcoded directly in this file. This is safe because:
#   - Public keys are designed to be shared (that's why they're called "public")
#   - They cannot be used to impersonate you or gain access
#   - This is standard practice in NixOS configurations
#
# Constitution alignment:
#   - Principle I: Declarative Configuration (users managed in Nix)
#   - Principle III: Security by Default (SSH keys required, password auth disabled)
#   - Principle V: Documentation as Code (inline comments)
#
# Feature 006-multi-user-support: Multi-user support with hardcoded SSH public keys

{
  config,
  pkgs,
  ...
}:

let
  # ─────────────────────────────────────────────────────────────────────────────
  # SSH Public Keys
  # ─────────────────────────────────────────────────────────────────────────────
  # Public keys are safe to commit - they're designed to be shared publicly.
  # Only private keys must be kept secret.

  # coal's SSH public key
  coalKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMYEMoAMxPAGD4AzBPCAYV6UiHrAeMm/AJIGXKCikkuc";

  # violino's SSH public key
  # TODO: Replace with violino's actual public key
  violinoKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPlaceholderReplaceWithViolinoKey";

in
{
  # ─────────────────────────────────────────────────────────────────────────────
  # Security Assertions
  # ─────────────────────────────────────────────────────────────────────────────

  assertions = [
    # Security: violino must NOT be in wheel group (no sudo access)
    {
      assertion = !(builtins.elem "wheel" config.users.users.violino.extraGroups);
      message = ''
        SECURITY: violino must not be in the wheel group.
        Only coal should have sudo access.
      '';
    }
  ];

  # ─────────────────────────────────────────────────────────────────────────────
  # User Accounts
  # ─────────────────────────────────────────────────────────────────────────────

  users.users = {
    # ───────────────────────────────────────────────────────────────────────────
    # coal - Primary Administrator
    # ───────────────────────────────────────────────────────────────────────────
    # coal has full admin access: sudo (wheel), docker, and code-server on port 8080
    coal = {
      isNormalUser = true;
      description = "coal - Primary Administrator";
      uid = 1000; # Explicit UID for consistency

      # Group memberships:
      # - wheel: sudo access for system administration
      # - networkmanager: network configuration
      # - docker: run containers without sudo
      extraGroups = [
        "wheel"
        "networkmanager"
        "docker"
      ];

      # Home directory with restricted permissions (700)
      home = "/home/coal";
      createHome = true;

      # SSH authorized keys (from environment variable)
      openssh.authorizedKeys.keys = [ coalKey ];

      # Default shell - Fish for modern CLI experience
      shell = pkgs.fish;
    };

    # ───────────────────────────────────────────────────────────────────────────
    # violino - Secondary User
    # ───────────────────────────────────────────────────────────────────────────
    # violino has dev access but NOT admin: docker group but no sudo (no wheel)
    # code-server on port 8081
    violino = {
      isNormalUser = true;
      description = "violino - Secondary User";
      uid = 1001; # Explicit UID for consistency

      # Group memberships:
      # - docker: run containers without sudo
      # - NO wheel: no sudo access (security requirement)
      extraGroups = [
        "docker"
      ];

      # Home directory with restricted permissions (700)
      home = "/home/violino";
      createHome = true;

      # SSH authorized keys (from environment variable)
      openssh.authorizedKeys.keys = [ violinoKey ];

      # Default shell - Fish for modern CLI experience
      shell = pkgs.fish;
    };
  };

  # ─────────────────────────────────────────────────────────────────────────────
  # System Configuration
  # ─────────────────────────────────────────────────────────────────────────────

  # Enable sudo for wheel group (passwordless for convenience in dev environment)
  # In production, consider removing NOPASSWD
  security.sudo.wheelNeedsPassword = false;

  # 1Password CLI system-level setup
  # Creates the onepassword-cli group and setgid wrapper for secure op binary
  programs._1password.enable = true;

  # ─────────────────────────────────────────────────────────────────────────────
  # Home Manager Configuration
  # ─────────────────────────────────────────────────────────────────────────────
  # Each user gets their own Home Manager configuration that imports the common
  # config and adds user-specific settings (git identity, custom abbreviations)

  home-manager.users = {
    coal = import ../../home/coal.nix;
    violino = import ../../home/violino.nix;
  };
}
