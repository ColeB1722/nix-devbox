# Home Manager Developer Profile
#
# Full developer toolkit including all CLI tools, shell configuration,
# Git, and development-specific tools (editors, multiplexers, AI tools, etc.).
#
# This profile is suitable for:
#   - Primary development machines
#   - Remote development servers
#   - Power users who want the full experience
#
# Usage:
#   imports = [ ../profiles/developer.nix ];

{ ... }:

{
  imports = [
    ../modules/cli.nix
    ../modules/fish.nix
    ../modules/git.nix
    ../modules/dev.nix
  ];

  # Let Home Manager manage itself
  programs.home-manager.enable = true;

  # Home Manager state version - determines which defaults are used
  home.stateVersion = "24.05";
}
