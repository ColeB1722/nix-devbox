# NixOS Tailscale SSH Module - OAuth-Based SSH Authentication
#
# This module configures Tailscale SSH for OAuth-based authentication,
# eliminating the need for committed SSH public keys.
#
# Constitution alignment:
#   - Principle I: Declarative Configuration (SSH auth in Nix)
#   - Principle II: Headless-First Design (SSH access)
#   - Principle III: Security by Default (OAuth > static keys)
#   - Principle IV: Modular and Reusable (separate module)
#   - Principle V: Documentation as Code (inline comments)
#
# How it works:
#   1. Tailscale SSH acts as an SSH server proxy
#   2. Users authenticate via their Tailscale identity (backed by OIDC providers)
#   3. Tailscale ACLs control which users can SSH to which hosts
#   4. No SSH keys need to be committed to the repository
#
# Prerequisites:
#   - Tailscale ACLs must be configured externally in Tailscale admin console
#   - Host must be tagged (e.g., tag:container-host) for ACL matching
#   - Users must have Tailscale client authenticated on their local machines
#
# Example Tailscale ACL (configure in admin.tailscale.com):
#   {
#     "tagOwners": {
#       "tag:container-host": ["autogroup:admin"]
#     },
#     "ssh": [{
#       "action": "check",
#       "src": ["group:devs"],
#       "dst": ["tag:container-host"],
#       "users": ["autogroup:nonroot"]
#     }]
#   }
#
# After deployment, tag the host:
#   sudo tailscale up --advertise-tags=tag:container-host

{ config, lib, ... }:

let
  cfg = config.devbox.tailscale.ssh;
  tailscaleCfg = config.devbox.tailscale;
in
{
  options.devbox.tailscale.ssh = {
    enable = lib.mkEnableOption "Tailscale SSH with OAuth authentication";

    disableOpenSSH = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to completely disable the OpenSSH server.
        When true, SSH is only available via Tailscale SSH.
        When false, OpenSSH is still enabled but only listens on Tailscale interface.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # ─────────────────────────────────────────────────────────────────────────
    # Assertions
    # ─────────────────────────────────────────────────────────────────────────

    assertions = [
      {
        assertion = tailscaleCfg.enable;
        message = ''
          Tailscale SSH requires Tailscale to be enabled.
          Set `devbox.tailscale.enable = true` to use Tailscale SSH.
        '';
      }
    ];

    # ─────────────────────────────────────────────────────────────────────────
    # Tailscale SSH Configuration
    # ─────────────────────────────────────────────────────────────────────────
    # Enable Tailscale's built-in SSH server which authenticates via Tailscale
    # identity rather than traditional SSH keys.

    services.tailscale = {
      # Tailscale SSH is controlled via ACLs, but we need to ensure the
      # tailscaled daemon is configured to accept SSH connections.
      # The actual SSH server behavior is controlled by Tailscale ACLs.
      extraUpFlags = lib.mkDefault [
        "--ssh"
      ];
    };

    # ─────────────────────────────────────────────────────────────────────────
    # OpenSSH Configuration
    # ─────────────────────────────────────────────────────────────────────────
    # Either disable OpenSSH entirely or restrict it to Tailscale interface only.

    services.openssh = {
      # Enable or disable based on disableOpenSSH option
      enable = !cfg.disableOpenSSH;

      settings = lib.mkIf (!cfg.disableOpenSSH) {
        # Note: SSH access is restricted to Tailscale interface via firewall rules
        # (tailscale0 is in trustedInterfaces). ListenAddress does not support CIDR
        # notation, so we rely on firewall rules instead of binding restrictions.

        # Disable password authentication (security best practice)
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;

        # Disable root login via OpenSSH
        PermitRootLogin = "no";

        # Only allow public key authentication as fallback
        # Tailscale SSH is the primary auth method
        PubkeyAuthentication = "yes";
      };
    };

    # ─────────────────────────────────────────────────────────────────────────
    # Firewall Configuration
    # ─────────────────────────────────────────────────────────────────────────
    # SSH port should only be accessible via Tailscale interface.
    # The firewall module handles trusting tailscale0, so SSH works there.
    # We explicitly do NOT open port 22 to the public internet.
    # Note: If other modules add port 22 to allowedTCPPorts, you may need
    # to override that in your host configuration.

    # ─────────────────────────────────────────────────────────────────────────
    # Documentation
    # ─────────────────────────────────────────────────────────────────────────

    warnings = lib.mkIf cfg.enable [
      ''
        Tailscale SSH is enabled. Remember to:
        1. Configure Tailscale ACLs in admin.tailscale.com
        2. Tag this host: sudo tailscale up --advertise-tags=tag:container-host
        3. Users must have Tailscale client authenticated to connect

        Example ACL for SSH access:
        {
          "ssh": [{
            "action": "check",
            "src": ["group:devs"],
            "dst": ["tag:container-host"],
            "users": ["autogroup:nonroot"]
          }]
        }
      ''
    ];
  };
}
