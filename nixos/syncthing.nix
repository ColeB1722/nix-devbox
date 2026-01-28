# NixOS Syncthing Module - Continuous File Synchronization
#
# This module provides Syncthing for peer-to-peer file synchronization
# between development machines. Access is restricted to the Tailscale network.
#
# Constitution alignment:
#   - Principle I: Declarative Configuration (Syncthing in Nix)
#   - Principle II: Headless-First Design (service with web UI for config)
#   - Principle III: Security by Default (Tailscale-only access via firewall)
#   - Principle IV: Modular and Reusable (configurable options, user-scoped)
#   - Principle V: Documentation as Code (inline comments)
#
# Required specialArgs:
#   users - User data attrset (see lib/schema.nix for schema)
#
# Note: Syncthing runs as a NixOS system service but operates under a specific
# user account with user-owned data directories. This satisfies the requirement
# for user-scoped operation while ensuring the service starts at boot.

{
  config,
  lib,
  users,
  ...
}:

let
  cfg = config.devbox.syncthing;
  # Default to first admin user if available, with safe empty list handling
  defaultUser =
    if users.adminUserNames != [ ] then
      builtins.head users.adminUserNames
    else if users.allUserNames != [ ] then
      builtins.head users.allUserNames
    else
      null; # Will be caught by assertion below
in
{
  # ─────────────────────────────────────────────────────────────────────────────
  # Module Options
  # ─────────────────────────────────────────────────────────────────────────────

  options.devbox.syncthing = {
    enable = lib.mkEnableOption "Syncthing file synchronization";

    user = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = defaultUser;
      description = ''
        User account to run Syncthing as.
        Syncthing will have access to this user's home directory.
        Defaults to the first admin user.
      '';
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/home/${cfg.user}/Sync";
      defaultText = lib.literalExpression ''"/home/''${cfg.user}/Sync"'';
      description = ''
        Default directory for synced files.
        This is where new sync folders will be created by default.
      '';
    };

    guiPort = lib.mkOption {
      type = lib.types.port;
      default = 8384;
      description = ''
        Port for Syncthing web GUI.
        This port is opened on the Tailscale interface only.
      '';
    };
  };

  # ─────────────────────────────────────────────────────────────────────────────
  # Module Configuration
  # ─────────────────────────────────────────────────────────────────────────────

  config = lib.mkIf cfg.enable {
    # ───────────────────────────────────────────────────────────────────────────
    # Syncthing Service
    # ───────────────────────────────────────────────────────────────────────────
    # Runs as system service but operates under the specified user account.
    # This ensures Syncthing starts at boot and syncs files even when
    # no user is logged in (important for headless servers).

    services.syncthing = {
      enable = true;

      # Run as specified user (not root)
      inherit (cfg) user;
      group = "users";

      # Data directories owned by the user
      inherit (cfg) dataDir;
      configDir = "/home/${cfg.user}/.config/syncthing";

      # Bind to all interfaces but firewall restricts to Tailscale
      guiAddress = "0.0.0.0:${toString cfg.guiPort}";

      # Don't open default ports - we control via Tailscale firewall
      openDefaultPorts = false;
    };

    # ───────────────────────────────────────────────────────────────────────────
    # Firewall Configuration
    # ───────────────────────────────────────────────────────────────────────────
    # All Syncthing ports are only accessible via Tailscale interface.
    # This ensures file sync and web UI are not exposed to public internet.

    networking.firewall.interfaces.tailscale0 = {
      # Web GUI port
      allowedTCPPorts = [
        cfg.guiPort
        22000 # Syncthing data transfer (TCP)
      ];
      allowedUDPPorts = [
        22000 # Syncthing data transfer (QUIC)
        21027 # Syncthing discovery
      ];
    };

    # ───────────────────────────────────────────────────────────────────────────
    # Safety Assertions
    # ───────────────────────────────────────────────────────────────────────────

    assertions = [
      {
        assertion = cfg.user != null;
        message = ''
          No users defined. Syncthing requires at least one user.
          Define users in lib/users.nix or set devbox.syncthing.user explicitly.
        '';
      }
      {
        assertion = cfg.user != null -> config.users.users ? ${cfg.user};
        message = ''
          Syncthing user '${cfg.user}' does not exist.
          The user must be defined in your users configuration.

          Either:
          1. Set devbox.syncthing.user to an existing user
          2. Add '${cfg.user}' to your users configuration
        '';
      }
    ];
  };
}
