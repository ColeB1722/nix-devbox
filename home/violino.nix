# Home Manager Configuration - Violino (Secondary User)
#
# Violino's personal Home Manager configuration. Imports common.nix for shared
# settings and adds Violino-specific customizations (git identity, etc).
#
# Feature 006-multi-user-support: Per-user Home Manager configuration

{ ... }:

{
  imports = [
    ./common.nix
  ];

  # Violino-specific configuration
  home = {
    username = "violino";
    homeDirectory = "/home/violino";
  };

  programs.git = {
    userName = "Violino";
    userEmail = "violino@example.com"; # TODO: Update with real email
  };

  # Violino-specific shell abbreviations (if any)
  # programs.fish.shellAbbrs = {
  #   # Add Violino-specific shortcuts here
  # };
}
