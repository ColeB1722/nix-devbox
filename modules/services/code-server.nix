# code-server Module - Browser-Based VS Code (Multi-User)
#
# This module enables code-server for multiple users, providing VS Code in a
# web browser for remote development. Each user gets their own instance on a
# dedicated port:
#   - coal (admin): port 8080
#   - violino (user): port 8081
#
# Security model:
#   - code-server binds to all interfaces (0.0.0.0)
#   - Access control is handled by Tailscale ACLs (defined in homelab-iac)
#   - Firewall trusts tailscale0 interface (see modules/networking/default.nix)
#   - No authentication in code-server itself (Tailscale provides identity)
#
# ACL policy (managed in homelab-iac/tailscale/main.tf):
#   - coal (admin): can access both 8080 and 8081 (full access for troubleshooting)
#   - violino (user): can only access 8081 (their own instance)
#
# Constitution alignment:
#   - Principle I: Declarative Configuration (service in Nix, ACLs in Terraform)
#   - Principle II: Headless-First Design (browser-based IDE, no GUI on server)
#   - Principle III: Security by Default (Tailscale ACLs control access)
#   - Principle IV: Modular and Reusable (separate service module)
#   - Principle V: Documentation as Code (inline comments)
#
# Access (from any device on tailnet with appropriate ACL permissions):
#   - coal: http://devbox:8080 or http://<tailscale-ip>:8080
#   - violino: http://devbox:8081 or http://<tailscale-ip>:8081
#
# Feature: 005-devtools-config (FR-013, FR-014, FR-015)
# Feature: 006-multi-user-support (per-user code-server instances)

{
  config,
  pkgs,
  ...
}:

let
  # Common code-server packages for the integrated terminal
  codeServerPackages = with pkgs; [
    git
    nixfmt-rfc-style # Nix formatter
    nil # Nix LSP
    statix # Nix linter
    deadnix # Dead code finder
  ];

  # Helper to create a code-server service for a user
  # NixOS services.code-server only supports a single instance, so we create
  # additional instances via systemd directly
  mkCodeServerService = user: port: {
    description = "code-server for ${user}";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];

    serviceConfig = {
      Type = "simple";
      User = user;
      Group = "users";
      # Bind to all interfaces - access control is handled by Tailscale ACLs
      ExecStart = "${pkgs.code-server}/bin/code-server --bind-addr 0.0.0.0:${toString port} --auth none --disable-telemetry --disable-update-check";
      Restart = "on-failure";
      RestartSec = 5;

      # Security hardening
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = "read-only";
      ReadWritePaths = [ "/home/${user}" ];
    };

    path = codeServerPackages;
  };

in
{
  # ─────────────────────────────────────────────────────────────────────────────
  # Security Assertion
  # ─────────────────────────────────────────────────────────────────────────────
  # code-server MUST only be accessible via Tailscale to prevent unauthorized access.
  # This assertion ensures Tailscale is enabled before code-server starts.
  # Actual access control is handled by Tailscale ACLs in homelab-iac.

  assertions = [
    {
      assertion = config.services.tailscale.enable;
      message = ''
        code-server requires Tailscale for secure remote access.
        Enable Tailscale in your host configuration:
          devbox.tailscale.enable = true;

        Access control is managed via Tailscale ACLs in homelab-iac.
      '';
    }
  ];

  # ─────────────────────────────────────────────────────────────────────────────
  # Per-User code-server Instances
  # ─────────────────────────────────────────────────────────────────────────────
  # Each user gets their own code-server instance on a dedicated port.
  # This provides isolation - each user's extensions, settings, and terminal
  # sessions are independent.

  systemd.services = {
    # coal's code-server on port 8080
    "code-server-coal" = mkCodeServerService "coal" 8080;

    # violino's code-server on port 8081
    "code-server-violino" = mkCodeServerService "violino" 8081;
  };

  # Ensure code-server package is available system-wide
  environment.systemPackages = [ pkgs.code-server ];

  # ─────────────────────────────────────────────────────────────────────────────
  # Network Access Model
  # ─────────────────────────────────────────────────────────────────────────────
  # code-server binds to 0.0.0.0 (all interfaces) but is NOT exposed publicly:
  #
  #   1. Firewall trusts only tailscale0 interface (modules/networking/default.nix)
  #   2. Tailscale ACLs control who can reach which ports (homelab-iac)
  #   3. No public firewall ports are opened
  #
  # This means:
  #   - Only Tailscale-authenticated users can reach code-server
  #   - ACLs determine which users can access which ports
  #   - Traffic is encrypted via WireGuard (Tailscale)
  #
  # To modify access permissions, update homelab-iac/tailscale/main.tf
}
