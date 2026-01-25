# NixOS Fish Module - System-Level Fish Shell Configuration
#
# Enables Fish shell at the system level, adding it to /etc/shells.
# User-level Fish configuration (aliases, abbreviations, etc.) is managed
# via Home Manager's programs.fish module in home/modules/fish.nix.
#
# Constitution alignment:
#   - Principle I: Declarative Configuration (shell in Nix)
#   - Principle II: Headless-First Design (CLI shell)
#   - Principle IV: Modular and Reusable (separate shell module)
#   - Principle V: Documentation as Code (inline comments)
#
# Why Fish?
#   - Superior out-of-box experience with syntax highlighting and autocompletions
#   - Better interactive features than bash/zsh without extensive configuration
#   - Excellent Home Manager integration via programs.fish

_:

{
  # Enable Fish shell system-wide
  # This adds fish to /etc/shells, allowing users to set it as their default shell
  programs.fish.enable = true;
}
