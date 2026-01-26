# Home Manager Workstation Profile
#
# Full development toolkit for local workstations (macOS, headful NixOS).
# Includes all CLI tools, shell configuration, Git, and development tools,
# but EXCLUDES remote access components (code-server, Zed remote).
#
# This profile is used for:
#   - macOS workstations (nix-darwin)
#   - Headful NixOS desktops
#
# For dev containers running on the orchestrator, use container.nix instead.
#
# Includes:
#   - cli.nix: Core CLI tools (ripgrep, fd, bat, eza, fzf, etc.)
#   - fish.nix: Fish shell with aliases and abbreviations
#   - git.nix: Git configuration with lazygit and gh
#   - dev.nix: Development tools (neovim, zellij, AI tools, languages)
#
# Does NOT include:
#   - remote-access.nix: Not needed for local development
#
# Constitution alignment:
#   - Principle IV: Modular and Reusable (composed from individual modules)
#   - Principle V: Documentation as Code (clear purpose documented)

{ lib, ... }:

{
  imports = [
    ../modules/cli.nix
    ../modules/fish.nix
    ../modules/git.nix
    ../modules/dev.nix
    # NOTE: remote-access.nix is intentionally NOT imported
    # Local workstations don't need code-server or Zed remote server
  ];

  # Let Home Manager manage itself
  programs.home-manager.enable = true;

  # Home Manager state version - determines which defaults are used
  # Use mkDefault so consumer/users.nix can override
  home.stateVersion = lib.mkDefault "24.05";
}
