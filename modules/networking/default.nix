# Networking Module - Firewall and Network Configuration
#
# This module configures the system firewall with a secure default-deny policy.
# Only Tailscale traffic is trusted; no public ports are exposed.
#
# Constitution alignment:
#   - Principle III: Security by Default (firewall deny-all, explicit allowlist)
#   - Principle V: Documentation as Code (inline comments)
#
# Security model:
#   - All incoming traffic is denied by default
#   - Tailscale interface (tailscale0) is fully trusted
#   - UDP 41641 is open for Tailscale P2P connections (avoids DERP relay)
#   - No TCP ports are exposed publicly

{ config, lib, pkgs, ... }:

{
  # Security assertion: Firewall MUST be enabled
  # This enforces Constitution Principle III (Security by Default)
  assertions = [
    {
      assertion = config.networking.firewall.enable;
      message = ''
        SECURITY VIOLATION: Firewall must be enabled.
        Constitution Principle III requires security by default.
        Set networking.firewall.enable = true.
      '';
    }
  ];

  # Enable the firewall with default-deny policy
  networking.firewall = {
    enable = true;

    # Trust all traffic from Tailscale network
    # This allows SSH and other services to be accessed via Tailscale
    # without exposing them to the public internet
    trustedInterfaces = [ "tailscale0" ];

    # Allow Tailscale's WireGuard port for direct P2P connections
    # This improves latency by avoiding relay servers
    allowedUDPPorts = [ config.services.tailscale.port ];

    # No TCP ports exposed publicly
    # All services are accessed via Tailscale only
    allowedTCPPorts = [ ];
  };

  # Use DHCP by default; can be overridden in host config
  networking.useDHCP = lib.mkDefault true;
}
