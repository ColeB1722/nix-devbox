# Tailscale Module - VPN Service Configuration
#
# This module enables Tailscale for secure remote access to the devbox.
# Tailscale provides zero-config VPN using WireGuard under the hood.
#
# Constitution alignment:
#   - Principle II: Headless-First Design (CLI-accessible VPN)
#   - Principle III: Security by Default (encrypted mesh network)
#   - Principle IV: Modular and Reusable (enable/disable pattern)
#   - Principle V: Documentation as Code (inline comments)
#
# Usage:
#   To enable:  Import this module in your host configuration
#   To disable: Remove from imports or set devbox.tailscale.enable = false
#
# Post-deployment:
#   Run `sudo tailscale up` once to authenticate with your tailnet.
#   Automated auth key provisioning is deferred to a future secret management feature.

{ config, lib, pkgs, ... }:

let
  cfg = config.devbox.tailscale;
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
      type = lib.types.enum [ "none" "client" "server" "both" ];
      default = "client";
      description = ''
        Routing features mode:
        - none: No routing features
        - client: Can reach other tailnet nodes (default)
        - server: Acts as subnet router or exit node
        - both: Client and server features
      '';
    };
  };

  # Module configuration - only applied when enabled
  config = lib.mkIf cfg.enable {
    # Enable Tailscale service
    services.tailscale = {
      enable = true;
      useRoutingFeatures = cfg.useRoutingFeatures;
      port = cfg.port;
    };

    # Ensure tailscale CLI is available
    environment.systemPackages = [ pkgs.tailscale ];
  };
}
