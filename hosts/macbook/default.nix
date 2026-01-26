# macOS Workstation Host Configuration
#
# This is the main nix-darwin configuration for macOS workstations.
# It imports the core darwin modules and configures the system for
# local development use.
#
# Features:
#   - Full CLI development toolkit via Home Manager
#   - Aerospace tiling window manager
#   - Fish shell as default
#   - Sensible macOS defaults for developers
#
# Usage:
#   # First-time bootstrap
#   nix run nix-darwin -- switch --flake .#macbook
#
#   # Subsequent updates
#   darwin-rebuild switch --flake .#macbook
#
# Constitution alignment:
#   - Principle I: Declarative Configuration (entire macOS config in Nix)
#   - Principle II: Headless-First Design (CLI tools, keyboard-driven)
#   - Principle IV: Modular and Reusable (composed from darwin modules)

{
  lib,
  pkgs,
  users ? { },
  ...
}:

{
  imports = [
    # Core macOS configuration (Nix settings, system defaults)
    ../../darwin/core.nix

    # Aerospace tiling window manager
    ../../darwin/aerospace.nix
  ];

  # ─────────────────────────────────────────────────────────────────────────────
  # Aerospace Configuration
  # ─────────────────────────────────────────────────────────────────────────────

  devbox.aerospace.enable = true;

  # ─────────────────────────────────────────────────────────────────────────────
  # Networking
  # ─────────────────────────────────────────────────────────────────────────────

  networking = {
    # Computer name (shown in Finder sidebar, etc.)
    # Override this in consumer configuration
    computerName = lib.mkDefault "macbook";

    # Hostname for networking
    hostName = lib.mkDefault "macbook";

    # Local hostname for Bonjour (.local)
    localHostName = lib.mkDefault "macbook";
  };

  # ─────────────────────────────────────────────────────────────────────────────
  # Users
  # ─────────────────────────────────────────────────────────────────────────────
  # On macOS, users are typically created via System Preferences.
  # nix-darwin can manage shell and home directory settings.

  # Note: Consumer configurations should override this with their actual users.
  # This is a placeholder for the example configuration.

  users.users = lib.mkIf (users ? allUserNames) (
    builtins.listToAttrs (
      map (
        name:
        let
          userData = users.${name} or { };
        in
        {
          inherit name;
          value = {
            # Home directory (macOS standard location)
            home = "/Users/${name}";

            # Default shell
            shell = pkgs.fish;

            # Description (shown in System Preferences)
            description = userData.description or name;
          };
        }
      ) users.allUserNames
    )
  );

  # ─────────────────────────────────────────────────────────────────────────────
  # Additional System Packages
  # ─────────────────────────────────────────────────────────────────────────────
  # Most packages are managed via Home Manager, but some system-level
  # packages are useful to have available globally.

  environment.systemPackages = with pkgs; [
    # Terminal emulators (user can choose their preferred)
    # alacritty  # GPU-accelerated terminal
    # kitty      # Feature-rich terminal

    # Useful system utilities
    mas # Mac App Store CLI (for installing App Store apps)
  ];

  # ─────────────────────────────────────────────────────────────────────────────
  # Homebrew Configuration (for GUI apps not in nixpkgs)
  # ─────────────────────────────────────────────────────────────────────────────
  # Aerospace is installed via Homebrew cask (see aerospace.nix).
  # Additional casks can be added here.

  homebrew = {
    # Already enabled by aerospace.nix

    # Mac App Store apps (via mas)
    # masApps = {
    #   "Xcode" = 497799835;
    # };

    # Additional Homebrew casks (GUI apps)
    casks = [
      # Uncomment apps as needed
      # "obsidian"        # Note-taking
      # "discord"         # Chat
      # "slack"           # Work chat
      # "zoom"            # Video calls
      # "docker"          # Docker Desktop (if needed)
      # "visual-studio-code"  # VS Code (if not using Zed)
    ];

    # Homebrew taps (additional repositories)
    taps = [
      # Already includes nikitabobko/tap for Aerospace
    ];
  };

  # ─────────────────────────────────────────────────────────────────────────────
  # Fonts
  # ─────────────────────────────────────────────────────────────────────────────
  # Install fonts system-wide for all applications

  fonts.packages = with pkgs; [
    # Nerd Fonts (patched fonts with icons)
    nerd-fonts.fira-code
    nerd-fonts.jetbrains-mono
    nerd-fonts.hack

    # Standard programming fonts
    fira-code
    jetbrains-mono
  ];

  # ─────────────────────────────────────────────────────────────────────────────
  # Tailscale (Optional)
  # ─────────────────────────────────────────────────────────────────────────────
  # If you want Tailscale on your Mac for connecting to dev containers

  # services.tailscale.enable = true;

  # ─────────────────────────────────────────────────────────────────────────────
  # Platform Configuration
  # ─────────────────────────────────────────────────────────────────────────────

  # Allow unfree packages (for things like 1Password CLI, etc.)
  nixpkgs.config.allowUnfree = true;

  # Used for backwards compatibility with older nix-darwin configs
  system.stateVersion = 4;
}
