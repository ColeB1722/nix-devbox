# code-server Module - Browser-Based VS Code
#
# This module enables code-server, providing VS Code in a web browser for
# remote development. Authentication is disabled because access is restricted
# to the Tailscale network.
#
# Constitution alignment:
#   - Principle I: Declarative Configuration (service in Nix)
#   - Principle II: Headless-First Design (browser-based IDE, no GUI on server)
#   - Principle III: Security by Default (localhost-only, Tailscale access)
#   - Principle IV: Modular and Reusable (separate service module)
#   - Principle V: Documentation as Code (inline comments)
#
# Access: http://localhost:8080 via Tailscale SSH tunnel or tailscale serve
#
# Feature: 005-devtools-config (FR-013, FR-014, FR-015)

{
  config,
  _lib,
  pkgs,
  ...
}:

{
  # ─────────────────────────────────────────────────────────────────────────────
  # Security Assertion
  # ─────────────────────────────────────────────────────────────────────────────
  # code-server MUST only be accessible via Tailscale to prevent unauthorized access.
  # This assertion ensures Tailscale is enabled before code-server starts.

  assertions = [
    {
      assertion = config.services.tailscale.enable;
      message = ''
        code-server requires Tailscale for secure remote access.
        Enable Tailscale in your host configuration:
          devbox.tailscale.enable = true;
      '';
    }
  ];

  # ─────────────────────────────────────────────────────────────────────────────
  # code-server Configuration
  # ─────────────────────────────────────────────────────────────────────────────

  services.code-server = {
    enable = true;

    # Bind to localhost only - access via Tailscale SSH tunnel
    # or use `tailscale serve --bg 8080` for HTTPS access
    host = "127.0.0.1";
    port = 8080;

    # Disable authentication - Tailscale provides network-level auth
    # Only users on your tailnet can reach this service
    auth = "none";

    # Run as the primary user
    user = "devuser";

    # Privacy settings
    disableTelemetry = true;
    disableUpdateCheck = true;

    # Tools available in the code-server integrated terminal
    # These are essential for Nix development within the IDE
    extraPackages = with pkgs; [
      git
      nixfmt-rfc-style # Nix formatter
      nil # Nix LSP
      statix # Nix linter
      deadnix # Dead code finder
    ];
  };

  # ─────────────────────────────────────────────────────────────────────────────
  # Firewall Configuration
  # ─────────────────────────────────────────────────────────────────────────────
  # Port 8080 is NOT opened on the public firewall.
  # Access is only via:
  #   1. SSH tunnel: ssh -L 8080:localhost:8080 devuser@devbox
  #   2. Tailscale serve: tailscale serve --bg 8080
  #   3. Direct Tailscale IP (if on same tailnet)

  # Note: Do NOT add port 8080 to networking.firewall.allowedTCPPorts
  # This would expose code-server to the public internet!
}
