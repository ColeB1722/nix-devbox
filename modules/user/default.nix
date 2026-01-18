# User Module - Multi-User Account and Home Manager Integration
#
# This module creates user accounts for coal (primary admin) and violino (secondary user)
# and integrates Home Manager for per-user environment management.
#
# SSH keys are injected via environment variables at build time:
#   - SSH_KEY_COAL: coal's SSH public key
#   - SSH_KEY_VIOLINO: violino's SSH public key
#
# If env vars are not set, placeholder keys are used (build succeeds, SSH fails at runtime).
# Set NIX_STRICT_KEYS=true to fail the build if keys are missing.
#
# Constitution alignment:
#   - Principle I: Declarative Configuration (users managed in Nix)
#   - Principle III: Security by Default (SSH keys required, password auth disabled)
#   - Principle V: Documentation as Code (inline comments)
#
# Feature 006-multi-user-support: Multi-user support with environment variable key injection

{
  config,
  lib,
  pkgs,
  ...
}:

let
  # ─────────────────────────────────────────────────────────────────────────────
  # SSH Key Environment Variable Injection
  # ─────────────────────────────────────────────────────────────────────────────
  # Keys are read from environment variables at build time.
  # This allows the repo to be public while keeping keys private.
  #
  # Usage:
  #   export SSH_KEY_COAL="ssh-ed25519 AAAA..."
  #   export SSH_KEY_VIOLINO="ssh-ed25519 AAAA..."
  #   nix flake check

  # Placeholder key used when env var is not set
  # This allows the build to succeed (for FlakeHub, CI) but SSH login will fail
  placeholderKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPlaceholderKeySSHLoginWillFail";

  # Read SSH keys from environment variables
  sshKeyCoal = builtins.getEnv "SSH_KEY_COAL";
  sshKeyViolino = builtins.getEnv "SSH_KEY_VIOLINO";

  # Check if strict mode is enabled (fail build if keys missing)
  strictKeys = (builtins.getEnv "NIX_STRICT_KEYS") == "true";

  # Helper to get key with fallback to placeholder (with warning)
  getKey =
    name: envValue:
    if envValue != "" then
      envValue
    else
      lib.warn ''
        [006-multi-user] SSH key for ${name} not set (${
          if name == "coal" then "SSH_KEY_COAL" else "SSH_KEY_VIOLINO"
        } env var is empty).
        Using placeholder key - SSH login will fail at runtime.
        Set the environment variable before rebuilding, or set NIX_STRICT_KEYS=true to fail the build.
      '' placeholderKey;

  # Final SSH keys (either from env or placeholder with warning)
  coalKey = getKey "coal" sshKeyCoal;
  violinoKey = getKey "violino" sshKeyViolino;

  # Check if keys are placeholders (for assertions)
  isPlaceholder = key: lib.hasPrefix "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPlaceholder" key;

in
{
  # ─────────────────────────────────────────────────────────────────────────────
  # Strict Mode Assertions
  # ─────────────────────────────────────────────────────────────────────────────
  # When NIX_STRICT_KEYS=true, fail the build if any SSH key is missing.
  # This is useful for production deployments.

  assertions = [
    {
      assertion = !strictKeys || !isPlaceholder coalKey;
      message = ''
        STRICT MODE: SSH key for coal is not set.
        Set SSH_KEY_COAL environment variable with coal's public key.
        Example: export SSH_KEY_COAL="ssh-ed25519 AAAA... coal@machine"
      '';
    }
    {
      assertion = !strictKeys || !isPlaceholder violinoKey;
      message = ''
        STRICT MODE: SSH key for violino is not set.
        Set SSH_KEY_VIOLINO environment variable with violino's public key.
        Example: export SSH_KEY_VIOLINO="ssh-ed25519 AAAA... violino@machine"
      '';
    }
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
