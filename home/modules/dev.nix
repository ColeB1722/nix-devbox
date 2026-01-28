# Home Manager Dev Module - Development Tools
#
# This module provides development-specific tools and configurations.
# These go beyond the basic CLI tools and are focused on software development.
#
# Sections:
#   - AI Coding Tools: opencode, claude-code, goose-cli
#   - Version Control Extensions: gh
#   - Package Managers / Runtimes: nodejs, uv, bun
#   - Infrastructure: terraform
#   - Secrets Management: 1password-cli
#   - Rust Toolchain: rustc, cargo, rustfmt, clippy
#
# Constitution alignment:
#   - Principle I: Declarative Configuration (dev tools in Nix)
#   - Principle II: Headless-First Design (CLI development tools)
#   - Principle V: Documentation as Code (inline comments)

{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # ─────────────────────────────────────────────────────────────────────────
    # AI Coding Tools
    # ─────────────────────────────────────────────────────────────────────────
    opencode # OpenCode CLI
    claude-code # Claude Code CLI (unfree - allowed in flake.nix)
    goose-cli # Block's AI agent CLI for terminal (not the DB migration tool)

    # ─────────────────────────────────────────────────────────────────────────
    # Version Control Extensions
    # ─────────────────────────────────────────────────────────────────────────
    gh # GitHub CLI (config in git.nix)

    # ─────────────────────────────────────────────────────────────────────────
    # Package Managers / Runtimes
    # ─────────────────────────────────────────────────────────────────────────
    nodejs # Includes npm
    uv # Python package manager (fast pip/venv replacement)
    bun # JavaScript runtime and package manager

    # ─────────────────────────────────────────────────────────────────────────
    # Infrastructure
    # ─────────────────────────────────────────────────────────────────────────
    terraform # Infrastructure as code (unfree - allowed in flake.nix)

    # ─────────────────────────────────────────────────────────────────────────
    # Secrets Management
    # ─────────────────────────────────────────────────────────────────────────
    _1password-cli # 1Password CLI (unfree - allowed in flake.nix)

    # ─────────────────────────────────────────────────────────────────────────
    # Rust Toolchain
    # ─────────────────────────────────────────────────────────────────────────
    # Core Rust development tools from nixpkgs (stable channel).
    # For nightly/specific versions, consider rust-overlay or fenix.
    rustc # Rust compiler
    cargo # Rust package manager and build tool
    rustfmt # Rust code formatter
    clippy # Rust linter with helpful suggestions
  ];

  programs = {
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
    # zellij - Modern Terminal Multiplexer
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
    # Tmux - Terminal Multiplexer (legacy)
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
  };
}
