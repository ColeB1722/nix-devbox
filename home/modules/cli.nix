# Home Manager CLI Module - Core Command-Line Tools
#
# This module provides the shared CLI toolkit installed for all users.
# These are the foundational tools that make up the "shared core" across
# all platforms (NixOS, Darwin, containers).
#
# Constitution alignment:
#   - Principle I: Declarative Configuration (user env in Nix)
#   - Principle II: Headless-First Design (CLI tools only)
#   - Principle V: Documentation as Code (inline comments)

{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # ─────────────────────────────────────────────────────────────────────────
    # Core Utilities
    # ─────────────────────────────────────────────────────────────────────────
    coreutils
    curl
    wget
    htop
    jq

    # ─────────────────────────────────────────────────────────────────────────
    # File Navigation and Search
    # ─────────────────────────────────────────────────────────────────────────
    tree
    ripgrep # rg - fast grep
    fd # Fast find alternative
    yazi # Terminal file manager with vim-like keybindings

    # ─────────────────────────────────────────────────────────────────────────
    # System Monitoring
    # ─────────────────────────────────────────────────────────────────────────
    btop
    ncdu

    # ─────────────────────────────────────────────────────────────────────────
    # Build Tools
    # ─────────────────────────────────────────────────────────────────────────
    just # Task runner
  ];

  programs = {
    # ─────────────────────────────────────────────────────────────────────────
    # fzf - Fuzzy Finder
    # ─────────────────────────────────────────────────────────────────────────
    # Provides fuzzy finding for history (Ctrl+R), files (Ctrl+T), and
    # directory navigation (Alt+C)
    fzf = {
      enable = true;
      enableFishIntegration = true;
      enableBashIntegration = true;

      # Use fd instead of find for better performance and .gitignore respect
      defaultCommand = "fd --type f --hidden --exclude .git";
      defaultOptions = [
        "--height 40%"
        "--layout=reverse"
        "--border"
      ];

      # Ctrl+T: File search
      fileWidgetCommand = "fd --type f --hidden --exclude .git";
      fileWidgetOptions = [ "--preview 'bat --color=always --line-range :50 {}'" ];

      # Alt+C: Directory search
      changeDirWidgetCommand = "fd --type d --hidden --exclude .git";
    };

    # ─────────────────────────────────────────────────────────────────────────
    # bat - Better cat
    # ─────────────────────────────────────────────────────────────────────────
    # Cat replacement with syntax highlighting, line numbers, and git integration
    bat = {
      enable = true;
      config = {
        theme = "TwoDark";
        pager = "less -FR";
      };
    };

    # ─────────────────────────────────────────────────────────────────────────
    # eza - Modern ls
    # ─────────────────────────────────────────────────────────────────────────
    # ls replacement with colors, icons, and git integration
    eza = {
      enable = true;
      enableFishIntegration = true;
      enableBashIntegration = true;
      icons = "auto";
      git = true;
    };

    # ─────────────────────────────────────────────────────────────────────────
    # Direnv - Automatic Environment Loading
    # ─────────────────────────────────────────────────────────────────────────
    direnv = {
      enable = true;
      enableBashIntegration = true;
      # enableFishIntegration is automatically true when fish is enabled
      nix-direnv.enable = true;
    };
  };
}
