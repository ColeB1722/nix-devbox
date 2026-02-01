# NixOS opnix Module - 1Password Secrets Management
#
# This module integrates opnix for declarative 1Password secrets management.
# Secrets are fetched from 1Password vaults at system activation time and
# stored securely in /run/secrets (tmpfs).
#
# Constitution alignment:
#   - Principle I: Declarative Configuration (secrets defined in Nix)
#   - Principle III: Security by Default (secrets in RAM, not on disk)
#   - Principle IV: Modular and Reusable (opt-in enable pattern)
#   - Principle V: Documentation as Code (inline comments)
#
# Prerequisites:
#   1. 1Password account with Service Accounts feature
#   2. Service account created at https://my.1password.com/developer
#   3. Service account token provisioned to tokenFile path
#
# Usage:
#   devbox.secrets.enable = true;
#   devbox.tailscale.authKeyReference = "op://Infrastructure/Tailscale/auth-key";
#
# Bootstrap (one-time per machine):
#   sudo opnix token set
#   # Paste your service account token when prompted
#
# Security model:
#   - Token stored at /etc/opnix-token (mode 0400, root only)
#   - Secrets decrypted to /run/secrets/* (tmpfs, RAM only)
#   - Service account should have minimal vault access (read-only)

{
  config,
  lib,
  ...
}:

let
  cfg = config.devbox.secrets;
in
{
  options.devbox.secrets = {
    enable = lib.mkEnableOption "1Password secrets management via opnix";

    tokenFile = lib.mkOption {
      type = lib.types.path;
      default = "/etc/opnix-token";
      description = ''
        Path to the 1Password service account token file.
        This file must be provisioned manually once per machine using:
          sudo opnix token set

        The file should be readable only by root (mode 0400).
      '';
    };

    secretsDir = lib.mkOption {
      type = lib.types.path;
      default = "/run/secrets";
      description = ''
        Directory where decrypted secrets are stored.
        This should be on tmpfs (RAM) for security.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # ─────────────────────────────────────────────────────────────────────────
    # opnix Configuration
    # ─────────────────────────────────────────────────────────────────────────
    # Enable the opnix service for 1Password secrets management.
    # Secrets are defined by other modules (e.g., tailscale.nix) that
    # add entries to services.onepassword-secrets.secrets.

    services.onepassword-secrets = {
      enable = true;
      inherit (cfg) tokenFile;
    };

    # ─────────────────────────────────────────────────────────────────────────
    # Documentation Warning
    # ─────────────────────────────────────────────────────────────────────────
    # Remind users about the bootstrap requirement.

    warnings = [
      ''
        1Password secrets management is enabled (devbox.secrets.enable = true).

        If this is a new machine, you must provision the service account token:
          sudo opnix token set
          # Paste your 1Password service account token when prompted

        Create a service account at: https://my.1password.com/developer
        Grant it read access to vaults containing your infrastructure secrets.
      ''
    ];
  };
}
