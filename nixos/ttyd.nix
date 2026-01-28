# NixOS ttyd Module - Web Terminal Sharing
#
# This module provides ttyd for sharing terminal sessions via web browser.
# Access is restricted to the Tailscale network for security.
#
# Constitution alignment:
#   - Principle I: Declarative Configuration (ttyd in Nix)
#   - Principle II: Headless-First Design (CLI tool with web interface for sharing)
#   - Principle III: Security by Default (Tailscale-only access via firewall)
#   - Principle IV: Modular and Reusable (configurable options)
#   - Principle V: Documentation as Code (inline comments)
#
# Usage:
#   ttyd is installed as a CLI tool when enabled. Users run it ad-hoc:
#     ttyd fish              # Share fish shell on default port
#     ttyd -p 8080 bash      # Share bash on custom port
#
#   Access via browser at http://<tailscale-hostname>:<port>

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.devbox.ttyd;
in
{
  # ─────────────────────────────────────────────────────────────────────────────
  # Module Options
  # ─────────────────────────────────────────────────────────────────────────────

  options.devbox.ttyd = {
    enable = lib.mkEnableOption "ttyd web terminal sharing";

    port = lib.mkOption {
      type = lib.types.port;
      default = 7681;
      description = ''
        Default port for ttyd web server.
        This port is opened on the Tailscale interface only.
      '';
    };

    shell = lib.mkOption {
      type = lib.types.str;
      default = "fish";
      description = ''
        Default shell to launch in web terminal.
        Users can override this when running ttyd manually.
      '';
    };
  };

  # ─────────────────────────────────────────────────────────────────────────────
  # Module Configuration
  # ─────────────────────────────────────────────────────────────────────────────

  config = lib.mkIf cfg.enable {
    # ───────────────────────────────────────────────────────────────────────────
    # Package Installation
    # ───────────────────────────────────────────────────────────────────────────
    # ttyd is installed as a CLI tool for ad-hoc terminal sharing.
    # Users invoke it manually when they want to share their terminal.

    environment.systemPackages = [ pkgs.ttyd ];

    # ───────────────────────────────────────────────────────────────────────────
    # Firewall Configuration
    # ───────────────────────────────────────────────────────────────────────────
    # Allow ttyd port ONLY on the Tailscale interface.
    # This ensures terminal sharing is not exposed to the public internet.

    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ cfg.port ];

    # ───────────────────────────────────────────────────────────────────────────
    # Note: No Persistent Service
    # ───────────────────────────────────────────────────────────────────────────
    # ttyd is designed for ad-hoc use. Users run:
    #   ttyd fish                    # Default shell
    #   ttyd -p 7681 fish            # Explicit port
    #   ttyd -c user:pass fish       # With authentication
    #   ttyd -R fish                 # Read-only mode
    #
    # A persistent systemd service could be added here if needed:
    #   systemd.services.ttyd = { ... };
  };
}
