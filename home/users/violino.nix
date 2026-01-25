# Home Manager Configuration - violino (Secondary User)
#
# violino's personal Home Manager configuration. Imports the developer profile
# for full tooling and adds violino-specific customizations (git identity, etc.).
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

  # violino-specific configuration
  home = {
    username = users.violino.name;
    homeDirectory = "/home/${users.violino.name}";
  };

  # Git identity
  programs.git = {
    userName = users.violino.gitUser;
    userEmail = users.violino.email;
  };

  # violino-specific shell abbreviations (if any)
  # programs.fish.shellAbbrs = {
  #   # Add violino-specific shortcuts here
  # };
}
