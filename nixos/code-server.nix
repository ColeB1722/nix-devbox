# NixOS code-server Module - Browser-Based VS Code (Multi-User)
#
# Enables code-server for multiple users, providing VS Code in a
# web browser for remote development. Each user gets their own instance
# on a dedicated port (defined in consumer's users.nix via codeServerPorts).
#
# Security model:
#   - code-server binds to all interfaces (0.0.0.0)
#   - Access control is handled by Tailscale ACLs (defined in homelab-iac)
#   - Firewall trusts tailscale0 interface (see nixos/firewall.nix)
#   - No authentication in code-server itself (Tailscale provides identity)
#
# Constitution alignment:
#   - Principle I: Declarative Configuration (service in Nix, ACLs in Terraform)
#   - Principle II: Headless-First Design (browser-based IDE, no GUI on server)
#   - Principle III: Security by Default (Tailscale ACLs control access)
#   - Principle IV: Modular and Reusable (accepts user data from consumer)
#   - Principle V: Documentation as Code (inline comments)
#
# Required specialArgs:
#   users - User data attrset with allUserNames and codeServerPorts
#
# Access (from any device on tailnet with appropriate ACL permissions):
#   http://devbox:<port> or http://<tailscale-ip>:<port>

{
  config,
  lib,
  pkgs,
  users,
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

  # Get port for a user (with fallback for users without explicit port assignment)
  getPort =
    name: index:
    if users ? codeServerPorts && users.codeServerPorts ? ${name} then
      users.codeServerPorts.${name}
    else
      8080 + index;

  # Create services for all users
  userServices = builtins.listToAttrs (
    lib.imap0 (index: name: {
      name = "code-server-${name}";
      value = mkCodeServerService name (getPort name index);
    }) users.allUserNames
  );

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
  #
  # Port assignments come from users.codeServerPorts (defined in consumer's users.nix)
  # If a user doesn't have an explicit port, they get 8080 + their index in allUserNames

  systemd.services = userServices;

  # Ensure code-server package is available system-wide
  environment.systemPackages = [ pkgs.code-server ];

  # ─────────────────────────────────────────────────────────────────────────────
  # Network Access Model
  # ─────────────────────────────────────────────────────────────────────────────
  # code-server binds to 0.0.0.0 (all interfaces) but is NOT exposed publicly:
  #
  #   1. Firewall trusts only tailscale0 interface (nixos/firewall.nix)
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
