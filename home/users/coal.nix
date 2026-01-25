# Home Manager Configuration - coal (Primary Administrator)
#
# coal's personal Home Manager configuration. Imports the developer profile
# for full tooling and adds coal-specific customizations (git identity, etc.).
#
# User data is sourced from lib/users.nix for consistency.

_:

let
  users = import ../../lib/users.nix;
in
{
  imports = [
    ../profiles/developer.nix
  ];

  # coal-specific configuration
  home = {
    username = users.coal.name;
    homeDirectory = "/home/${users.coal.name}";
  };

  # Git identity
  programs.git = {
    userName = users.coal.gitUser;
    userEmail = users.coal.email;
  };

  # coal-specific shell abbreviations (if any)
  # programs.fish.shellAbbrs = {
  #   # Add coal-specific shortcuts here
  # };
}
