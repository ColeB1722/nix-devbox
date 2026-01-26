# Home Manager Remote Access Module - code-server and Zed Remote
#
# This module configures remote development access tools for dev containers.
# It is imported by the container profile and should NOT be imported by
# local workstation profiles (macOS, headful NixOS).
#
# Includes:
#   - code-server: Browser-based VS Code
#   - zed-editor: Zed remote server capabilities
#
# Constitution alignment:
#   - Principle I: Declarative Configuration (user env in Nix)
#   - Principle II: Headless-First Design (remote access tools for headless containers)
#   - Principle IV: Modular and Reusable (separate module for remote-only components)

{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # ─────────────────────────────────────────────────────────────────────────
    # code-server - Browser-based VS Code
    # ─────────────────────────────────────────────────────────────────────────
    # Provides VS Code in a browser, accessible via Tailscale
    # Port 8080 by default, authentication via Tailscale identity
    code-server

    # ─────────────────────────────────────────────────────────────────────────
    # Zed Editor - Remote Server Support
    # ─────────────────────────────────────────────────────────────────────────
    # Zed remote works via SSH - the client initiates the connection
    # and runs the remote CLI automatically. No persistent server needed.
    zed-editor
  ];

  # ─────────────────────────────────────────────────────────────────────────
  # code-server Configuration
  # ─────────────────────────────────────────────────────────────────────────
  # Configuration file for code-server settings
  # Authentication is handled by Tailscale, so we disable built-in auth
  xdg.configFile."code-server/config.yaml".text = ''
    # code-server configuration for dev containers
    # Authentication handled by Tailscale identity - no password needed
    bind-addr: 0.0.0.0:8080
    auth: none
    cert: false

    # Disable telemetry
    disable-telemetry: true
    disable-update-check: true

    # User data directory (persisted in container volume)
    user-data-dir: ~/.local/share/code-server

    # Extensions directory
    extensions-dir: ~/.local/share/code-server/extensions
  '';

  # ─────────────────────────────────────────────────────────────────────────
  # VS Code / code-server Extensions
  # ─────────────────────────────────────────────────────────────────────────
  # Pre-install common extensions for development
  # Users can install additional extensions via the UI
  home.file.".local/share/code-server/extensions/.gitkeep".text = "";

  # ─────────────────────────────────────────────────────────────────────────
  # Zed Editor Configuration
  # ─────────────────────────────────────────────────────────────────────────
  # Zed settings for remote server operation
  # The remote server is started on-demand by the Zed client via SSH
  xdg.configFile."zed/settings.json".text = builtins.toJSON {
    # Telemetry disabled for privacy
    telemetry = {
      diagnostics = false;
      metrics = false;
    };

    # Terminal settings
    terminal = {
      shell = {
        program = "fish";
      };
      font_family = "monospace";
      font_size = 14;
    };

    # Editor settings
    tab_size = 2;
    soft_wrap = "editor_width";
    format_on_save = "on";

    # Theme - use a dark theme suitable for remote work
    theme = {
      mode = "dark";
      dark = "One Dark";
      light = "One Light";
    };

    # Git integration
    git = {
      enabled = true;
      autoFetch = true;
    };

    # Language-specific settings
    languages = {
      Nix = {
        tab_size = 2;
        format_on_save = "on";
      };
      Python = {
        tab_size = 4;
      };
      JavaScript = {
        tab_size = 2;
      };
      TypeScript = {
        tab_size = 2;
      };
    };
  };

  # ─────────────────────────────────────────────────────────────────────────
  # Shell Integration
  # ─────────────────────────────────────────────────────────────────────────
  # Add convenient aliases for remote access tools
  # Fish aliases - the programs.fish module handles whether these are applied
  programs.fish.shellAliases = {
    # Start code-server in background (for manual control)
    cs = "code-server --bind-addr 0.0.0.0:8080";
    # Open current directory in code-server
    code = "code-server";
  };

  programs.bash.shellAliases = {
    cs = "code-server --bind-addr 0.0.0.0:8080";
    code = "code-server";
  };
}
