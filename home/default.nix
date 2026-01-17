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
# Packages installed here are user-specific and managed separately from
# system packages. This separation allows different users to have different
# tool configurations on the same machine.

{ config, lib, pkgs, ... }:

{
  # Home Manager needs these to manage the user's home directory
  home.username = "devuser";
  home.homeDirectory = "/home/devuser";

  # Home Manager state version
  # This determines which Home Manager defaults are used
  home.stateVersion = "24.05";

  # Let Home Manager manage itself
  programs.home-manager.enable = true;

  # Git configuration
  programs.git = {
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

  # Vim/Neovim as the default editor
  programs.neovim = {
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

  # Bash shell configuration
  programs.bash = {
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

  # Common CLI utilities
  home.packages = with pkgs; [
    # Core utilities
    coreutils
    curl
    wget
    htop
    tree
    ripgrep
    fd
    jq

    # Development tools
    tmux
    direnv

    # System monitoring
    btop
    ncdu
  ];

  # Tmux configuration for terminal multiplexing
  programs.tmux = {
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

  # Direnv for automatic environment loading
  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    nix-direnv.enable = true;
  };
}
