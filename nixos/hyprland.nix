# NixOS Hyprland Module - Wayland Compositor (Opt-in)
#
# This module provides Hyprland as an optional Wayland compositor for
# headed NixOS installations. It is opt-in and disabled by default.
#
# Constitution alignment:
#   - Principle I: Declarative Configuration (Hyprland in Nix)
#   - Principle II: Headless-First Design - ⚠️ VIOLATION (justified)
#   - Principle IV: Modular and Reusable (opt-in, isolated module)
#   - Principle V: Documentation as Code (inline comments)
#
# CONSTITUTION VIOLATION JUSTIFICATION (Principle II):
#   Hyprland is a GUI desktop compositor, which violates the headless-first
#   principle. This violation is justified and mitigated because:
#   - The module is opt-in (disabled by default)
#   - It is the lowest priority (P4) feature
#   - It is isolated and does not affect headless configurations
#   - Future headed NixOS installations require a compositor
#   See plan.md Complexity Tracking for full justification.
#
# Note: This module should NOT be enabled on:
#   - Headless servers
#   - WSL configurations (no display)
#   - Systems without GPU/display hardware

{
  config,
  lib,
  ...
}:

let
  cfg = config.devbox.hyprland;
in
{
  # ─────────────────────────────────────────────────────────────────────────────
  # Module Options
  # ─────────────────────────────────────────────────────────────────────────────

  options.devbox.hyprland = {
    enable = lib.mkEnableOption "Hyprland Wayland compositor (headed systems only)";

    xwayland = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Enable XWayland for X11 application compatibility.
        Most legacy applications require this to run on Wayland.
      '';
    };
  };

  # ─────────────────────────────────────────────────────────────────────────────
  # Module Configuration
  # ─────────────────────────────────────────────────────────────────────────────

  config = lib.mkIf cfg.enable {
    # ───────────────────────────────────────────────────────────────────────────
    # Hyprland Compositor
    # ───────────────────────────────────────────────────────────────────────────
    # Enable Hyprland as the Wayland compositor.
    # User-specific configuration should be done via Home Manager:
    #   wayland.windowManager.hyprland.settings = { ... };

    programs.hyprland = {
      enable = true;
      xwayland.enable = cfg.xwayland;
    };

    # ───────────────────────────────────────────────────────────────────────────
    # Display Manager
    # ───────────────────────────────────────────────────────────────────────────
    # SDDM provides a graphical login screen and session selection.
    # This allows users to choose between Hyprland and other sessions.

    services.xserver.enable = true;
    services.displayManager.sddm = {
      enable = true;
      wayland.enable = true;
    };

    # ───────────────────────────────────────────────────────────────────────────
    # Warnings for Incompatible Configurations
    # ───────────────────────────────────────────────────────────────────────────

    warnings = lib.optional (cfg.enable && config.wsl.enable or false) ''
      Hyprland is enabled but this appears to be a WSL configuration.
      Hyprland requires a physical display and will not work in WSL.

      To fix: Set devbox.hyprland.enable = false in your WSL configuration.
    '';
  };
}
