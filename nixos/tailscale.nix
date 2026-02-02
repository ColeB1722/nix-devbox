# NixOS Tailscale Module - VPN Service Configuration
#
# Enables Tailscale for secure remote access to the devbox.
# Tailscale provides zero-config VPN using WireGuard under the hood.
#
# Constitution alignment:
#   - Principle II: Headless-First Design (CLI-accessible VPN)
#   - Principle III: Security by Default (encrypted mesh network)
#   - Principle IV: Modular and Reusable (enable/disable pattern)
#   - Principle V: Documentation as Code (inline comments)
#
# Usage:
#   To enable:  Import this module and set devbox.tailscale.enable = true
#   To disable: Set devbox.tailscale.enable = false
#
# Authentication options:
#   1. Manual (default): Run `sudo tailscale up` once to authenticate
#   2. Automatic (with opnix): Set authKeyReference to auto-authenticate
#
# Example with opnix:
#   devbox.secrets.enable = true;
#   devbox.tailscale = {
#     enable = true;
#     authKeyReference = "op://Infrastructure/Tailscale/auth-key";
#   };

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.devbox.tailscale;
  secretsEnabled = config.devbox.secrets.enable or false;
in
{
  # Module options for enable/disable pattern
  options.devbox.tailscale = {
    enable = lib.mkEnableOption "Tailscale VPN service";

    port = lib.mkOption {
      type = lib.types.port;
      default = 41641;
      description = "WireGuard port for Tailscale P2P connections";
    };

    useRoutingFeatures = lib.mkOption {
      type = lib.types.enum [
        "none"
        "client"
        "server"
        "both"
      ];
      default = "client";
      description = ''
        Routing features mode:
        - none: No routing features
        - client: Can reach other tailnet nodes (default)
        - server: Acts as subnet router or exit node
        - both: Client and server features
      '';
    };

    authKeyReference = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "op://Infrastructure/Tailscale/auth-key";
      description = ''
        1Password secret reference for Tailscale auth key.

        When set (and devbox.secrets.enable = true), Tailscale will
        automatically authenticate using the key fetched from 1Password.
        The auth key is only needed for initial registration; subsequent
        reboots use stored state in /var/lib/tailscale.

        When null, manual authentication with `sudo tailscale up` is required.

        To create an auth key:
          1. Go to https://login.tailscale.com/admin/settings/keys
          2. Generate an auth key (reusable recommended for servers)
          3. Store it in 1Password: op://Vault/Item/field

        Note: Auth keys can be configured as reusable, ephemeral, or
        pre-authorized. For servers, reusable + pre-authorized is typical.
      '';
    };
  };

  # Module configuration - only applied when enabled
  config = lib.mkIf cfg.enable {
    # ─────────────────────────────────────────────────────────────────────────
    # Assertions
    # ─────────────────────────────────────────────────────────────────────────

    assertions = [
      {
        assertion = cfg.authKeyReference != null -> secretsEnabled;
        message = ''
          Tailscale authKeyReference requires secrets management to be enabled.
          Either:
            1. Set `devbox.secrets.enable = true` to use opnix
            2. Remove authKeyReference and use manual `tailscale up`
        '';
      }
    ];

    # ─────────────────────────────────────────────────────────────────────────
    # opnix Secret Definition (conditional)
    # ─────────────────────────────────────────────────────────────────────────
    # When authKeyReference is set and secrets are enabled, define the secret
    # in opnix. The secret will be fetched from 1Password at activation time.

    services.onepassword-secrets.secrets = lib.mkIf (cfg.authKeyReference != null && secretsEnabled) {
      tailscaleAuthKey = {
        reference = cfg.authKeyReference;
        mode = "0400";
        # Restart tailscaled if the auth key changes (rare, but possible)
        services = [ "tailscaled" ];
      };
    };

    # ─────────────────────────────────────────────────────────────────────────
    # Tailscale Service Configuration
    # ─────────────────────────────────────────────────────────────────────────

    services.tailscale = {
      enable = true;
      inherit (cfg) useRoutingFeatures port;

      # Use auth key file if opnix is providing it
      authKeyFile = lib.mkIf (
        cfg.authKeyReference != null && secretsEnabled
      ) config.services.onepassword-secrets.secretPaths.tailscaleAuthKey;
    };

    # Ensure tailscale CLI is available
    environment.systemPackages = [ pkgs.tailscale ];
  };
}
