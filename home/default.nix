# Home Manager Configuration - Default Entry Point
#
# This file exists for backwards compatibility. The multi-user setup uses
# per-user configs (coal.nix, violino.nix) which import common.nix.
#
# For the current multi-user setup, this file is not directly used.
# See: modules/user/default.nix for Home Manager user assignments.
#
# Feature 006-multi-user-support: Replaced with per-user configs

{ ... }:

{
  # Default to coal's config for backwards compatibility
  imports = [ ./coal.nix ];
}
