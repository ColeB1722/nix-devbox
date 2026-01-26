# nix-darwin Aerospace Module - Tiling Window Manager for macOS
#
# This module provides Aerospace tiling window manager configuration.
# Aerospace is a modern, fast tiling window manager for macOS inspired
# by i3 and other Linux tiling WMs.
#
# Features:
#   - Automatic tiling with customizable layouts
#   - Workspace management (virtual desktops)
#   - Vim-style keybindings
#   - Tree-based window organization
#
# Constitution alignment:
#   - Principle I: Declarative Configuration (WM config in Nix)
#   - Principle II: Headless-First Design (keyboard-driven workflow)
#   - Principle V: Documentation as Code (keybindings documented)

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.devbox.aerospace;

  # Aerospace configuration in TOML format
  aerospaceConfig = pkgs.writeText "aerospace.toml" ''
    # ─────────────────────────────────────────────────────────────────────────────
    # Aerospace Configuration
    # ─────────────────────────────────────────────────────────────────────────────
    # Documentation: https://nikitabobko.github.io/AeroSpace/guide

    # Start AeroSpace at login
    start-at-login = true

    # Normalizations - automatically fix window issues
    enable-normalization-flatten-containers = true
    enable-normalization-opposite-orientation-for-nested-containers = true

    # Mouse follows focus
    on-focused-monitor-changed = ['move-mouse monitor-lazy-center']
    on-focus-changed = ['move-mouse window-lazy-center']

    # Visual feedback
    accordion-padding = 30

    # Default root container orientation
    default-root-container-orientation = 'auto'

    # Default layout (tiles or accordion)
    default-root-container-layout = 'tiles'

    # Gaps between windows
    [gaps]
    inner.horizontal = 10
    inner.vertical = 10
    outer.left = 10
    outer.bottom = 10
    outer.top = 10
    outer.right = 10

    # ─────────────────────────────────────────────────────────────────────────────
    # Mode: Main (default)
    # ─────────────────────────────────────────────────────────────────────────────
    # Alt is the main modifier key

    [mode.main.binding]
    # ─────────────────────────────────────────────────────────────────────────────
    # Focus Movement (Alt + H/J/K/L)
    # ─────────────────────────────────────────────────────────────────────────────
    alt-h = 'focus left'
    alt-j = 'focus down'
    alt-k = 'focus up'
    alt-l = 'focus right'

    # ─────────────────────────────────────────────────────────────────────────────
    # Window Movement (Alt + Shift + H/J/K/L)
    # ─────────────────────────────────────────────────────────────────────────────
    alt-shift-h = 'move left'
    alt-shift-j = 'move down'
    alt-shift-k = 'move up'
    alt-shift-l = 'move right'

    # ─────────────────────────────────────────────────────────────────────────────
    # Workspace Switching (Alt + 1-9)
    # ─────────────────────────────────────────────────────────────────────────────
    alt-1 = 'workspace 1'
    alt-2 = 'workspace 2'
    alt-3 = 'workspace 3'
    alt-4 = 'workspace 4'
    alt-5 = 'workspace 5'
    alt-6 = 'workspace 6'
    alt-7 = 'workspace 7'
    alt-8 = 'workspace 8'
    alt-9 = 'workspace 9'

    # ─────────────────────────────────────────────────────────────────────────────
    # Move Window to Workspace (Alt + Shift + 1-9)
    # ─────────────────────────────────────────────────────────────────────────────
    alt-shift-1 = 'move-node-to-workspace 1'
    alt-shift-2 = 'move-node-to-workspace 2'
    alt-shift-3 = 'move-node-to-workspace 3'
    alt-shift-4 = 'move-node-to-workspace 4'
    alt-shift-5 = 'move-node-to-workspace 5'
    alt-shift-6 = 'move-node-to-workspace 6'
    alt-shift-7 = 'move-node-to-workspace 7'
    alt-shift-8 = 'move-node-to-workspace 8'
    alt-shift-9 = 'move-node-to-workspace 9'

    # ─────────────────────────────────────────────────────────────────────────────
    # Layout Controls
    # ─────────────────────────────────────────────────────────────────────────────
    # Toggle fullscreen
    alt-f = 'fullscreen'

    # Toggle floating
    alt-shift-f = 'layout floating tiling'

    # Toggle split orientation (horizontal/vertical)
    alt-slash = 'layout tiles horizontal vertical'

    # Toggle between tiles and accordion
    alt-comma = 'layout accordion tiles'

    # ─────────────────────────────────────────────────────────────────────────────
    # Resize Mode
    # ─────────────────────────────────────────────────────────────────────────────
    alt-r = 'mode resize'

    # ─────────────────────────────────────────────────────────────────────────────
    # Service Mode
    # ─────────────────────────────────────────────────────────────────────────────
    alt-shift-semicolon = 'mode service'

    # ─────────────────────────────────────────────────────────────────────────────
    # Monitor Movement
    # ─────────────────────────────────────────────────────────────────────────────
    # Focus next/previous monitor
    alt-tab = 'workspace-back-and-forth'
    alt-shift-tab = 'move-workspace-to-monitor --wrap-around next'

    # ─────────────────────────────────────────────────────────────────────────────
    # Window Management
    # ─────────────────────────────────────────────────────────────────────────────
    # Close focused window
    alt-shift-q = 'close'

    # Enter join mode (for joining windows into splits)
    # Using alt-shift-i to avoid conflict with alt-j (focus down)
    alt-shift-i = 'mode join'

    # ─────────────────────────────────────────────────────────────────────────────
    # Mode: Resize
    # ─────────────────────────────────────────────────────────────────────────────
    # Enter with Alt+R, exit with Escape

    [mode.resize.binding]
    # Resize with H/J/K/L
    h = 'resize width -50'
    j = 'resize height +50'
    k = 'resize height -50'
    l = 'resize width +50'

    # Fine-grained resize with Shift
    shift-h = 'resize width -10'
    shift-j = 'resize height +10'
    shift-k = 'resize height -10'
    shift-l = 'resize width +10'

    # Balance sizes
    b = 'balance-sizes'

    # Exit resize mode
    enter = 'mode main'
    esc = 'mode main'

    # ─────────────────────────────────────────────────────────────────────────────
    # Mode: Join
    # ─────────────────────────────────────────────────────────────────────────────
    # Join windows into splits - enter with Alt+J

    [mode.join.binding]
    # Join with adjacent window using H/J/K/L
    h = ['join-with left', 'mode main']
    j = ['join-with down', 'mode main']
    k = ['join-with up', 'mode main']
    l = ['join-with right', 'mode main']

    # Exit join mode
    enter = 'mode main'
    esc = 'mode main'

    # ─────────────────────────────────────────────────────────────────────────────
    # Mode: Service
    # ─────────────────────────────────────────────────────────────────────────────
    # Administrative commands - enter with Alt+Shift+;

    [mode.service.binding]
    # Reload configuration
    r = ['reload-config', 'mode main']

    # Flatten workspace tree
    f = ['flatten-workspace-tree', 'mode main']

    # Close all windows on workspace
    c = ['close-all-windows-but-current', 'mode main']

    # Exit service mode
    esc = 'mode main'

    # ─────────────────────────────────────────────────────────────────────────────
    # Application-Specific Rules
    # ─────────────────────────────────────────────────────────────────────────────
    # Float certain windows by default

    [[on-window-detected]]
    if.app-id = 'com.apple.systempreferences'
    run = 'layout floating'

    [[on-window-detected]]
    if.app-id = 'com.apple.finder'
    if.window-title-regex-substring = 'Copy|Move|Delete|Connecting'
    run = 'layout floating'

    [[on-window-detected]]
    if.app-id = 'com.1password.1password'
    run = 'layout floating'

    [[on-window-detected]]
    if.app-id = 'com.apple.calculator'
    run = 'layout floating'

    # ─────────────────────────────────────────────────────────────────────────────
    # Workspace Assignments
    # ─────────────────────────────────────────────────────────────────────────────
    # Assign specific apps to workspaces (optional)

    # Browsers to workspace 1
    # [[on-window-detected]]
    # if.app-id = 'com.apple.Safari'
    # run = 'move-node-to-workspace 1'

    # Terminals to workspace 2
    # [[on-window-detected]]
    # if.app-id = 'com.apple.Terminal'
    # run = 'move-node-to-workspace 2'

    # Code editors to workspace 3
    # [[on-window-detected]]
    # if.app-id = 'dev.zed.Zed'
    # run = 'move-node-to-workspace 3'
  '';

in
{
  options.devbox.aerospace = {
    enable = lib.mkEnableOption "Aerospace tiling window manager";

    configFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Custom Aerospace configuration file. If null, uses the default
        configuration provided by this module.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # ─────────────────────────────────────────────────────────────────────────────
    # Install Aerospace
    # ─────────────────────────────────────────────────────────────────────────────

    # Aerospace is distributed as a macOS app bundle via Homebrew Casks
    # We use homebrew integration since it's not in nixpkgs
    homebrew = {
      enable = true;
      casks = [ "nikitabobko/tap/aerospace" ];

      # Don't remove other casks, only manage aerospace
      onActivation.cleanup = lib.mkDefault "none";
    };

    # ─────────────────────────────────────────────────────────────────────────────
    # Configuration File
    # ─────────────────────────────────────────────────────────────────────────────

    # Link config file to ~/.config/aerospace/aerospace.toml
    system.activationScripts.postUserActivation.text = ''
      # Create aerospace config directory
      mkdir -p ~/.config/aerospace

      # Link configuration file
      ${
        if cfg.configFile != null then
          ''
            ln -sf ${cfg.configFile} ~/.config/aerospace/aerospace.toml
          ''
        else
          ''
            ln -sf ${aerospaceConfig} ~/.config/aerospace/aerospace.toml
          ''
      }

      echo "Aerospace configuration installed to ~/.config/aerospace/aerospace.toml"
    '';

    # ─────────────────────────────────────────────────────────────────────────────
    # Launch Agent (auto-start)
    # ─────────────────────────────────────────────────────────────────────────────
    # Aerospace manages its own auto-start via the config, but we can also
    # ensure it's running after activation

    # Note: The 'start-at-login = true' in aerospace.toml handles auto-start.
    # This activation script ensures it's running after a darwin-rebuild.

    system.activationScripts.postActivation.text = ''
      # Start Aerospace if not running (after darwin-rebuild)
      if ! pgrep -x "AeroSpace" > /dev/null; then
        echo "Starting Aerospace..."
        open -a AeroSpace || true
      fi
    '';
  };
}
