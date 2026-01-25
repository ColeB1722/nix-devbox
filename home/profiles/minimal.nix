# Home Manager Minimal Profile
#
# The essential toolkit for any user. Provides core CLI tools,
# Fish shell, and basic Git configuration.
#
# This profile is suitable for:
#   - Lightweight environments
#   - Container base images
#   - Users who want a minimal setup
#
# Usage:
#   imports = [ ../profiles/minimal.nix ];

{ lib, ... }:

{
  imports = [
    ../modules/cli.nix
    ../modules/fish.nix
    ../modules/git.nix
  ];

  # Let Home Manager manage itself
  programs.home-manager.enable = true;

  # Home Manager state version - determines which defaults are used
  # Use mkDefault so consumer/users.nix can override
  home.stateVersion = lib.mkDefault "24.05";
}
