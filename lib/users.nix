# Shared User Data Library
#
# Centralized user definitions consumed by both NixOS and Darwin modules.
# This file contains only DATA (names, UIDs, SSH keys), not configuration.
#
# Usage:
#   let users = import ../lib/users.nix; in
#   users.coal.sshKeys
#
# Why centralize?
#   - Single source of truth for user identity across platforms
#   - SSH keys, UIDs, and metadata defined once
#   - NixOS and Darwin modules import this and apply platform-specific config

{
  # ─────────────────────────────────────────────────────────────────────────────
  # coal - Primary Administrator
  # ─────────────────────────────────────────────────────────────────────────────
  coal = {
    name = "coal";
    uid = 1000;
    description = "coal - Primary Administrator";
    email = "colebateman1722@gmail.com";
    gitUser = "coal-bap";
    isAdmin = true; # Has sudo/wheel access

    # SSH public keys (safe to share - that's why they're "public")
    sshKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMYEMoAMxPAGD4AzBPCAYV6UiHrAeMm/AJIGXKCikkuc"
    ];

    # Groups beyond the basics (platform modules add wheel, docker, etc.)
    extraGroups = [
      "networkmanager"
    ];
  };

  # ─────────────────────────────────────────────────────────────────────────────
  # violino - Secondary User
  # ─────────────────────────────────────────────────────────────────────────────
  violino = {
    name = "violino";
    uid = 1001;
    description = "violino - Secondary User";
    email = "violino@example.com"; # TODO: Update with real email
    gitUser = "Violino";
    isAdmin = false; # No sudo access

    # SSH public keys
    # TODO: Replace placeholder with violino's actual public key
    sshKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPlaceholderReplaceWithViolinoKey"
    ];

    # Groups beyond the basics
    extraGroups = [ ];
  };

  # ─────────────────────────────────────────────────────────────────────────────
  # Helper: Get all user names as a list
  # ─────────────────────────────────────────────────────────────────────────────
  allUserNames = [
    "coal"
    "violino"
  ];

  # ─────────────────────────────────────────────────────────────────────────────
  # Helper: Get admin user names (those with isAdmin = true)
  # ─────────────────────────────────────────────────────────────────────────────
  adminUserNames = [ "coal" ];

  # ─────────────────────────────────────────────────────────────────────────────
  # code-server port assignments
  # ─────────────────────────────────────────────────────────────────────────────
  codeServerPorts = {
    coal = 8080;
    violino = 8081;
  };
}
