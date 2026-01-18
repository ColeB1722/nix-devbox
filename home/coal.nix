# Home Manager Configuration - coal (Primary Administrator)
#
# coal's personal Home Manager configuration. Imports common.nix for shared
# settings and adds coal-specific customizations (git identity, etc).
#
# Feature 006-multi-user-support: Per-user Home Manager configuration

{ ... }:

{
  imports = [
    ./common.nix
  ];

  # coal-specific configuration
  home = {
    username = "coal";
    homeDirectory = "/home/coal";
  };

  programs.git = {
    userName = "coal-bap";
    userEmail = "colebateman1722@gmail.com";
  };

  # coal-specific shell abbreviations (if any)
  # programs.fish.shellAbbrs = {
  #   # Add coal-specific shortcuts here
  # };
}
