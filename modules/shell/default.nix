# Shell Module - System-Level Fish Shell Configuration
#
# This module enables Fish shell at the system level, adding it to /etc/shells.
# User-level Fish configuration (aliases, abbreviations, etc.) is managed in
# home/default.nix via Home Manager's programs.fish module.
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
#
# Feature: 005-devtools-config (FR-001, FR-002, FR-003)

{ _config, ... }:

{
  # Enable Fish shell system-wide
  # This adds fish to /etc/shells, allowing users to set it as their default shell
  programs.fish.enable = true;
}
