# Home Manager Fish Module - Shell Configuration
#
# This module provides Fish shell configuration for all users.
# System-level Fish enablement is in nixos/fish.nix; this handles
# the user experience (aliases, abbreviations, prompt, etc.).
#
# Constitution alignment:
#   - Principle I: Declarative Configuration (shell config in Nix)
#   - Principle II: Headless-First Design (CLI shell)
#   - Principle V: Documentation as Code (inline comments)

_:

{
  programs.fish = {
    enable = true;

    # ─────────────────────────────────────────────────────────────────────────
    # Abbreviations
    # ─────────────────────────────────────────────────────────────────────────
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

    # ─────────────────────────────────────────────────────────────────────────
    # Aliases
    # ─────────────────────────────────────────────────────────────────────────
    # Aliases replace commands entirely

    shellAliases = {
      # Use eza instead of ls (eza config in cli.nix)
      ls = "eza";
      ll = "eza -l";
      la = "eza -la";
      lt = "eza --tree";

      # Use bat instead of cat (bat config in cli.nix)
      cat = "bat";

      # Directory navigation
      ".." = "cd ..";
      "..." = "cd ../..";
    };

    # ─────────────────────────────────────────────────────────────────────────
    # Shell Initialization
    # ─────────────────────────────────────────────────────────────────────────

    interactiveShellInit = ''
      # Disable the greeting message
      set -g fish_greeting

      # Add Bun global bin directory to PATH
      # This allows globally installed bun packages to be accessible
      if test -d ~/.bun/bin
        fish_add_path -p ~/.bun/bin
      end
    '';
  };

  # ─────────────────────────────────────────────────────────────────────────────
  # Bash - Fallback Shell
  # ─────────────────────────────────────────────────────────────────────────────
  # Keep bash configured as fallback; Fish is the primary shell

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
}
