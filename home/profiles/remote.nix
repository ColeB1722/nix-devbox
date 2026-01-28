# Home Manager Remote Profile
#
# Full development toolkit for headless or remote systems.
# Includes all CLI tools, shell configuration, Git, development tools,
# and remote access components (code-server, Zed remote).
#
# This profile is intended for:
#   - Headless NixOS servers accessed via SSH
#   - Remote development machines
#   - Any system where IDE access is needed via browser or remote protocol
#
# For local workstations (macOS, headful NixOS), use workstation.nix instead.
#
# Includes:
#   - cli.nix: Core CLI tools (ripgrep, fd, bat, eza, fzf, etc.)
#   - fish.nix: Fish shell with aliases and abbreviations
#   - git.nix: Git configuration with lazygit and gh
#   - dev.nix: Development tools (neovim, zellij, AI tools, languages)
#   - remote-access.nix: code-server and Zed remote for IDE access

{ lib, ... }:

{
  imports = [
    ../modules/cli.nix
    ../modules/fish.nix
    ../modules/git.nix
    ../modules/dev.nix
    ../modules/remote-access.nix
  ];

  # Let Home Manager manage itself
  programs.home-manager.enable = true;

  # Home Manager state version - determines which defaults are used
  # Use mkDefault so consumer/users.nix can override
  home.stateVersion = lib.mkDefault "24.05";
}
