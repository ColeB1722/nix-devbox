# nix-darwin Core Module - Base macOS System Configuration
#
# This module provides the foundational macOS configuration for workstations.
# It handles system-level settings that cannot be managed by Home Manager alone.
#
# Includes:
#   - Nix daemon configuration
#   - macOS system defaults (Finder, Dock, etc.)
#   - Security settings
#   - Keyboard and input settings
#
# Constitution alignment:
#   - Principle I: Declarative Configuration (macOS settings in Nix)
#   - Principle III: Security by Default (sensible security defaults)
#   - Principle V: Documentation as Code (inline comments)

{
  pkgs,
  ...
}:

{
  # ─────────────────────────────────────────────────────────────────────────────
  # Nix Configuration
  # ─────────────────────────────────────────────────────────────────────────────

  nix = {
    # Enable flakes and new nix command
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];

      # Recommended binary caches
      substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
      ];

      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];

      # Allow wheel group users to use nix
      trusted-users = [
        "root"
        "@admin"
      ];
    };

    # Automatic garbage collection
    gc = {
      automatic = true;
      interval = {
        Weekday = 0; # Sunday
        Hour = 3;
        Minute = 0;
      };
      options = "--delete-older-than 30d";
    };

    # Optimize store automatically
    optimise.automatic = true;
  };

  # ─────────────────────────────────────────────────────────────────────────────
  # System Packages
  # ─────────────────────────────────────────────────────────────────────────────
  # Base packages available system-wide (most tools go in Home Manager)

  environment.systemPackages = with pkgs; [
    # Core utilities
    coreutils
    gnused
    gnugrep

    # Version control (system-wide for git operations)
    git
  ];

  # ─────────────────────────────────────────────────────────────────────────────
  # Shell Configuration
  # ─────────────────────────────────────────────────────────────────────────────

  # Enable fish shell system-wide
  programs.fish.enable = true;

  # Add fish to /etc/shells
  environment.shells = [ pkgs.fish ];

  # ─────────────────────────────────────────────────────────────────────────────
  # macOS System Configuration
  # ─────────────────────────────────────────────────────────────────────────────
  # Consolidated system.* attributes (defaults, activation scripts, state version)

  system = {
    # ───────────────────────────────────────────────────────────────────────────
    # macOS System Defaults
    # ───────────────────────────────────────────────────────────────────────────
    # These settings are applied via `defaults write` commands

    defaults = {
      # ─────────────────────────────────────────────────────────────────────────
      # Finder Settings
      # ─────────────────────────────────────────────────────────────────────────
      finder = {
        # Show all file extensions
        AppleShowAllExtensions = true;

        # Show hidden files
        AppleShowAllFiles = true;

        # Show path bar at bottom
        ShowPathbar = true;

        # Show status bar at bottom
        ShowStatusBar = true;

        # Use list view by default
        FXPreferredViewStyle = "Nlsv";

        # Allow quitting Finder via Cmd+Q
        QuitMenuItem = true;

        # Disable warning when changing file extension
        FXEnableExtensionChangeWarning = false;

        # Search current folder by default
        FXDefaultSearchScope = "SCcf";
      };

      # ─────────────────────────────────────────────────────────────────────────
      # Dock Settings
      # ─────────────────────────────────────────────────────────────────────────
      dock = {
        # Auto-hide the dock
        autohide = true;

        # Remove delay for auto-hide
        autohide-delay = 0.0;

        # Speed up auto-hide animation
        autohide-time-modifier = 0.4;

        # Don't show recent applications
        show-recents = false;

        # Minimize windows into application icon
        minimize-to-application = true;

        # Don't rearrange spaces based on recent use
        mru-spaces = false;

        # Smaller dock icons
        tilesize = 48;

        # Don't animate opening applications
        launchanim = false;

        # Show indicator lights for open applications
        show-process-indicators = true;
      };

      # ─────────────────────────────────────────────────────────────────────────
      # Global System Settings (NSGlobalDomain)
      # ─────────────────────────────────────────────────────────────────────────
      NSGlobalDomain = {
        # Keyboard settings
        # Fast key repeat rate
        KeyRepeat = 2;
        InitialKeyRepeat = 15;

        # Disable press-and-hold for keys (enables key repeat)
        ApplePressAndHoldEnabled = false;

        # Enable full keyboard access for all controls
        AppleKeyboardUIMode = 3;

        # Interface style
        # Use dark mode
        AppleInterfaceStyle = "Dark";

        # Disable automatic capitalization
        NSAutomaticCapitalizationEnabled = false;

        # Disable smart dashes
        NSAutomaticDashSubstitutionEnabled = false;

        # Disable automatic period substitution
        NSAutomaticPeriodSubstitutionEnabled = false;

        # Disable smart quotes
        NSAutomaticQuoteSubstitutionEnabled = false;

        # Disable auto-correct
        NSAutomaticSpellingCorrectionEnabled = false;

        # Expand save panel by default
        NSNavPanelExpandedStateForSaveMode = true;
        NSNavPanelExpandedStateForSaveMode2 = true;

        # Expand print panel by default
        PMPrintingExpandedStateForPrint = true;
        PMPrintingExpandedStateForPrint2 = true;

        # Save to disk (not iCloud) by default
        NSDocumentSaveNewDocumentsToCloud = false;
      };

      # ─────────────────────────────────────────────────────────────────────────
      # Trackpad Settings
      # ─────────────────────────────────────────────────────────────────────────
      trackpad = {
        # Enable tap to click
        Clicking = true;

        # Enable three-finger drag
        TrackpadThreeFingerDrag = true;
      };

      # ─────────────────────────────────────────────────────────────────────────
      # Login Window Settings
      # ─────────────────────────────────────────────────────────────────────────
      loginwindow = {
        # Disable guest account
        GuestEnabled = false;

        # Show login window as name and password fields
        SHOWFULLNAME = true;
      };

      # ─────────────────────────────────────────────────────────────────────────
      # Screensaver and Lock Settings
      # ─────────────────────────────────────────────────────────────────────────
      screensaver = {
        # Require password after sleep or screensaver
        askForPassword = true;

        # Require password immediately
        askForPasswordDelay = 0;
      };

      # ─────────────────────────────────────────────────────────────────────────
      # Screenshots
      # ─────────────────────────────────────────────────────────────────────────
      # Note: location is set via activation script below because tilde (~)
      # doesn't expand when passed through system.defaults
      screencapture = {
        # Save screenshots as PNG
        type = "png";

        # Disable shadow in screenshots
        disable-shadow = true;
      };
    };

    # ───────────────────────────────────────────────────────────────────────────
    # Custom Defaults (not covered by nix-darwin options)
    # ───────────────────────────────────────────────────────────────────────────

    activationScripts.postUserActivation.text = ''
      # Create Screenshots directory and set as screenshot location
      # (Using activation script because ~ doesn't expand in system.defaults)
      mkdir -p "$HOME/Screenshots"
      defaults write com.apple.screencapture location -string "$HOME/Screenshots"

      # Disable Spotlight indexing for developer directories
      # (run manually if needed: sudo mdutil -i off /path/to/folder)

      # Show battery percentage in menu bar
      defaults write com.apple.menuextra.battery ShowPercent -string "YES"

      # Enable subpixel font rendering on non-Apple LCDs
      defaults write NSGlobalDomain AppleFontSmoothing -int 1

      # Disable the "Are you sure you want to open this application?" dialog
      defaults write com.apple.LaunchServices LSQuarantine -bool false
    '';

    # ───────────────────────────────────────────────────────────────────────────
    # System State Version
    # ───────────────────────────────────────────────────────────────────────────
    # Used for backwards compatibility with older nix-darwin configurations

    stateVersion = 4;
  };

  # ─────────────────────────────────────────────────────────────────────────────
  # Security Settings
  # ─────────────────────────────────────────────────────────────────────────────

  security = {
    # Allow Touch ID for sudo
    pam.enableSudoTouchIdAuth = true;
  };

  # ─────────────────────────────────────────────────────────────────────────────
  # Homebrew (Optional - for GUI apps not in nixpkgs)
  # ─────────────────────────────────────────────────────────────────────────────
  # Uncomment if you need Homebrew for GUI apps

  # homebrew = {
  #   enable = true;
  #   onActivation = {
  #     autoUpdate = true;
  #     cleanup = "zap";
  #   };
  #   casks = [
  #     # Add GUI apps here if not available in nixpkgs
  #     # "obsidian"
  #     # "discord"
  #   ];
  # };
}
