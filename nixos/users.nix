# NixOS Users Module - Multi-User Account Configuration
#
# Creates user accounts and integrates Home Manager for per-user environment
# management. User data (SSH keys, UIDs, etc.) is sourced from lib/users.nix.
#
# Constitution alignment:
#   - Principle I: Declarative Configuration (users managed in Nix)
#   - Principle III: Security by Default (SSH keys required, password auth disabled)
#   - Principle V: Documentation as Code (inline comments)

{
  config,
  pkgs,
  ...
}:

let
  users = import ../lib/users.nix;
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
      inherit (users.coal) description uid;

      # Group memberships:
      # - wheel: sudo access for system administration
      # - docker: run containers without sudo
      # - plus any extra groups from lib/users.nix
      extraGroups = [
        "wheel"
        "docker"
      ]
      ++ users.coal.extraGroups;

      # Home directory with restricted permissions (700)
      home = "/home/${users.coal.name}";
      createHome = true;

      # SSH authorized keys from lib/users.nix
      openssh.authorizedKeys.keys = users.coal.sshKeys;

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
      inherit (users.violino) description uid;

      # Group memberships:
      # - docker: run containers without sudo
      # - NO wheel: no sudo access (security requirement)
      extraGroups = [
        "docker"
      ]
      ++ users.violino.extraGroups;

      # Home directory with restricted permissions (700)
      home = "/home/${users.violino.name}";
      createHome = true;

      # SSH authorized keys from lib/users.nix
      openssh.authorizedKeys.keys = users.violino.sshKeys;

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
  # profile and adds user-specific settings (git identity, custom abbreviations)

  home-manager.users = {
    coal = import ../home/users/coal.nix;
    violino = import ../home/users/violino.nix;
  };
}
