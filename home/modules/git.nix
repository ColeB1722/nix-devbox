# Home Manager Git Module - Version Control Configuration
#
# This module provides base Git configuration for all users.
# User-specific settings (userName, userEmail) are set in per-user configs.
#
# Constitution alignment:
#   - Principle I: Declarative Configuration (git config in Nix)
#   - Principle V: Documentation as Code (inline comments)

{ pkgs, ... }:

{
  programs = {
    git = {
      enable = true;

      extraConfig = {
        # Default branch name for new repositories
        init.defaultBranch = "main";

        # Rebase by default when pulling (cleaner history)
        pull.rebase = true;

        # Automatically set up remote tracking branch on first push
        push.autoSetupRemote = true;

        # Use GitHub CLI for credential management
        credential.helper = "!${pkgs.gh}/bin/gh auth git-credential";

        # Better diff algorithm
        diff.algorithm = "histogram";

        # Show original in conflict markers
        merge.conflictstyle = "diff3";

        # Automatically prune deleted remote branches
        fetch.prune = true;

        # Color output
        color.ui = "auto";
      };

      # Global gitignore patterns
      ignores = [
        # macOS
        ".DS_Store"
        ".AppleDouble"
        ".LSOverride"

        # Editors
        "*.swp"
        "*.swo"
        "*~"
        ".idea/"
        ".vscode/"
        "*.sublime-*"

        # Nix
        "result"
        "result-*"

        # direnv
        ".direnv/"
        ".envrc.local"
      ];
    };

    # ─────────────────────────────────────────────────────────────────────────
    # lazygit - Git TUI
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
    # GitHub CLI
    # ─────────────────────────────────────────────────────────────────────────
    # CLI for GitHub operations (issues, PRs, repos, etc.)
    gh = {
      enable = true;
      settings = {
        git_protocol = "ssh";
        prompt = "enabled";
      };
    };
  };
}
