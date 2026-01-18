# Home Manager Configuration - User Environment
#
# This module configures the user's shell environment, editor, and common tools.
# Managed by Home Manager for declarative user environment configuration.
#
# Constitution alignment:
#   - Principle I: Declarative Configuration (user env in Nix)
#   - Principle II: Headless-First Design (CLI tools only)
#   - Principle V: Documentation as Code (inline comments)
#
# Feature 005-devtools-config: Enhanced shell environment with modern CLI tools
#   - Fish shell with abbreviations and aliases (FR-001, FR-002, FR-003)
#   - fzf integration for fuzzy finding (FR-005)
#   - bat for syntax-highlighted cat (FR-004)
#   - eza for modern ls replacement (FR-006)
#   - Additional tools added progressively through user stories

{
  _config,
  _lib,
  pkgs,
  ...
}:

{
  # Home Manager needs these to manage the user's home directory
  home = {
    username = "devuser";
    homeDirectory = "/home/devuser";
    # Home Manager state version - determines which defaults are used
    stateVersion = "24.05";

    # ─────────────────────────────────────────────────────────────────────────
    # CLI Packages
    # ─────────────────────────────────────────────────────────────────────────
    # Common CLI utilities installed for all users
    # Note: Some tools (fzf, bat, eza) are also configured via programs.* below
    # for better integration, but are included here to ensure availability

    packages = with pkgs; [
      # Core utilities
      coreutils
      curl
      wget
      htop
      jq

      # File navigation and search (FR-004)
      tree
      ripgrep # rg - fast grep
      fd # Fast find alternative

      # Development tools
      direnv

      # System monitoring
      btop
      ncdu

      # ─────────────────────────────────────────────────────────────────────────
      # Feature 005-devtools-config: Additional Development Tools
      # ─────────────────────────────────────────────────────────────────────────

      # AI Coding Tools (FR-010, FR-011) - US3
      opencode # OpenCode CLI
      claude-code # Claude Code CLI (unfree - allowed in flake.nix)

      # Version Control (FR-018, FR-019) - US6
      gh # GitHub CLI

      # Package Managers (FR-020, FR-021) - US7
      nodejs # Includes npm
      uv # Python package manager

      # Infrastructure (FR-022) - US8
      terraform # Infrastructure as code (unfree - allowed in flake.nix)

      # Secrets Management (FR-023) - US9
      _1password-cli # 1Password CLI (unfree - allowed in flake.nix)
    ];
  };

  programs = {
    # Let Home Manager manage itself
    home-manager.enable = true;

    # ─────────────────────────────────────────────────────────────────────────
    # Fish Shell Configuration (FR-001, FR-002, FR-003)
    # ─────────────────────────────────────────────────────────────────────────
    # Modern shell with better defaults than bash. System-level fish is enabled
    # in modules/shell/default.nix; this configures the user experience.

    fish = {
      enable = true;

      # Abbreviations expand when you press space (shows full command)
      # Better for learning and transparency than aliases
      shellAbbrs = {
        # Git shortcuts
        g = "git";
        ga = "git add";
        gaa = "git add --all";
        gc = "git commit";
        gcm = "git commit -m";
        gco = "git checkout";
        gd = "git diff";
        gst = "git status";
        gp = "git push";
        gpl = "git pull";

        # Nix/NixOS shortcuts
        nrs = "sudo nixos-rebuild switch --flake .";
        nrb = "nixos-rebuild build --flake .";
        nfu = "nix flake update";

        # Docker shortcuts
        dc = "docker compose";
        dps = "docker ps";

        # Common tools
        j = "just";
        lg = "lazygit";
      };

      # Aliases replace commands entirely (FR-006 - eza as ls replacement)
      shellAliases = {
        # Use eza instead of ls
        ls = "eza";
        ll = "eza -l";
        la = "eza -la";
        lt = "eza --tree";

        # Use bat instead of cat
        cat = "bat";

        # Directory navigation
        ".." = "cd ..";
        "..." = "cd ../..";
      };

      # Shell initialization
      interactiveShellInit = ''
        # Disable the greeting message
        set -g fish_greeting
      '';
    };

    # ─────────────────────────────────────────────────────────────────────────
    # fzf - Fuzzy Finder (FR-005)
    # ─────────────────────────────────────────────────────────────────────────
    # Provides fuzzy finding for history (Ctrl+R), files (Ctrl+T), and
    # directory navigation (Alt+C)

    fzf = {
      enable = true;
      enableFishIntegration = true;

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
    # bat - Better cat (FR-004)
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
    # eza - Modern ls (FR-006)
    # ─────────────────────────────────────────────────────────────────────────
    # ls replacement with colors, icons, and git integration

    eza = {
      enable = true;
      enableFishIntegration = true;
      icons = "auto";
      git = true;
    };

    # ─────────────────────────────────────────────────────────────────────────
    # Git Configuration
    # ─────────────────────────────────────────────────────────────────────────

    git = {
      enable = true;
      # TODO: Configure your git identity
      userName = "Dev User";
      userEmail = "devuser@example.com";

      extraConfig = {
        init.defaultBranch = "main";
        pull.rebase = true;
        push.autoSetupRemote = true;
      };
    };

    # ─────────────────────────────────────────────────────────────────────────
    # Neovim - Default Editor
    # ─────────────────────────────────────────────────────────────────────────

    neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;

      extraConfig = ''
        " Basic sensible defaults
        set number
        set relativenumber
        set expandtab
        set tabstop=2
        set shiftwidth=2
        set autoindent
        set smartindent
        set mouse=a
        set clipboard=unnamedplus
      '';
    };

    # ─────────────────────────────────────────────────────────────────────────
    # Bash - Fallback Shell
    # ─────────────────────────────────────────────────────────────────────────
    # Keep bash configured as fallback; Fish is the primary shell

    bash = {
      enable = true;
      enableCompletion = true;

      shellAliases = {
        ll = "ls -la";
        ".." = "cd ..";
        "..." = "cd ../..";
        gs = "git status";
        gc = "git commit";
        gp = "git push";
        gl = "git log --oneline";
      };
    };

    # ─────────────────────────────────────────────────────────────────────────
    # zellij - Modern Terminal Multiplexer (FR-016, FR-017) - US5
    # ─────────────────────────────────────────────────────────────────────────
    # Primary terminal multiplexer for persistent sessions

    zellij = {
      enable = true;
      settings = {
        default_shell = "fish";
        theme = "default";
        pane_frames = true;
      };
    };

    # ─────────────────────────────────────────────────────────────────────────
    # lazygit - Git TUI (FR-018) - US6
    # ─────────────────────────────────────────────────────────────────────────
    # Terminal UI for git operations

    lazygit = {
      enable = true;
      settings = {
        gui = {
          theme = {
            lightTheme = false;
          };
        };
      };
    };

    # ─────────────────────────────────────────────────────────────────────────
    # Tmux - Terminal Multiplexer (legacy, kept for compatibility)
    # ─────────────────────────────────────────────────────────────────────────
    # Kept as fallback; zellij is now the primary multiplexer

    tmux = {
      enable = true;
      terminal = "screen-256color";
      historyLimit = 10000;

      extraConfig = ''
        # Use Ctrl+a as prefix (like screen)
        unbind C-b
        set -g prefix C-a
        bind C-a send-prefix

        # Mouse support
        set -g mouse on

        # Start windows and panes at 1, not 0
        set -g base-index 1
        setw -g pane-base-index 1
      '';
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

  # ─────────────────────────────────────────────────────────────────────────────
  # Zed Remote Server (FR-014) - US4
  # ─────────────────────────────────────────────────────────────────────────────
  # Provides Zed editor remote server for connecting Zed desktop clients.
  # Note: zed-editor.remote_server may require nixpkgs-unstable or an overlay.
  # Uncomment when available in your nixpkgs version.

  # home.file.".zed_server" = {
  #   source = "${pkgs.zed-editor.remote_server}/bin";
  #   recursive = true;
  # };
}
