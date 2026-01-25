# NixOS Users Module - Multi-User Account Configuration
#
# Creates user accounts and integrates Home Manager for per-user environment
# management. User data is provided by consumers via `specialArgs`.
#
# Constitution alignment:
#   - Principle I: Declarative Configuration (users managed in Nix)
#   - Principle III: Security by Default (SSH keys required, password auth disabled)
#   - Principle IV: Modular and Reusable (accepts user data from consumer)
#   - Principle V: Documentation as Code (inline comments)
#
# Required specialArgs:
#   users - User data attrset (see lib/schema.nix for schema)
#
# Usage:
#   nixpkgs.lib.nixosSystem {
#     specialArgs = { users = import ./users.nix; };
#     modules = [ ./nixos/users.nix ];
#   };

{
  config,
  lib,
  pkgs,
  users,
  ...
}:

let
  # Import schema validation
  schema = import ../lib/schema.nix { inherit lib; };

  # Helper to create a user configuration from user data
  mkUserConfig = _name: userData: {
    isNormalUser = true;
    inherit (userData) description uid;

    # Group memberships:
    # - wheel: sudo access (only if isAdmin = true)
    # - docker: run containers without sudo
    # - plus any extra groups from user data
    extraGroups =
      (lib.optional userData.isAdmin "wheel") ++ [ "docker" ] ++ (userData.extraGroups or [ ]);

    # Home directory with restricted permissions (700)
    home = "/home/${userData.name}";
    createHome = true;

    # SSH authorized keys from user data
    openssh.authorizedKeys.keys = userData.sshKeys;

    # Default shell - Fish for modern CLI experience
    shell = pkgs.fish;
  };

in
{
  # ─────────────────────────────────────────────────────────────────────────────
  # Schema Validation
  # ─────────────────────────────────────────────────────────────────────────────
  # Validate user data at evaluation time - fails with clear error messages
  # if required fields are missing or invalid

  assertions = [
    {
      assertion = schema.validateUsers users;
      message = "User data validation failed. See error messages above.";
    }
  ]
  # ─────────────────────────────────────────────────────────────────────────────
  # Security Assertions
  # ─────────────────────────────────────────────────────────────────────────────
  # Non-admin users must NOT be in the wheel group
  ++ (map (name: {
    assertion =
      !(users.${name}.isAdmin or false)
      -> !(builtins.elem "wheel" (config.users.users.${name}.extraGroups or [ ]));
    message = ''
      SECURITY: User '${name}' has isAdmin = false but is in the wheel group.
      Non-admin users must not have sudo access.
    '';
  }) users.allUserNames);

  # ─────────────────────────────────────────────────────────────────────────────
  # User Accounts
  # ─────────────────────────────────────────────────────────────────────────────
  # Dynamically create user accounts for all users defined in users.allUserNames

  users.users = builtins.listToAttrs (
    map (name: {
      inherit name;
      value = mkUserConfig name users.${name};
    }) users.allUserNames
  );

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
  # Home Manager Integration
  # ─────────────────────────────────────────────────────────────────────────────
  # This module sets up Home Manager integration but does NOT configure per-user
  # HM settings. Per-user configuration (profiles, git identity, etc.) is handled by:
  #   - lib/mkHost.nix (for consumers using the helper functions)
  #   - Consumer's flake.nix (for direct configuration)
  #
  # This avoids duplicate configuration and potential merge conflicts.

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;

    # Pass users data to Home Manager modules
    extraSpecialArgs = { inherit users; };

    # Per-user HM config is set by mkHost.nix or consumer's flake.nix
    # This module only provides the integration scaffolding
  };
}
