# NixOS Podman Module - Rootless Container Runtime
#
# This module provides Podman as a rootless, daemonless container runtime.
# It serves as a Docker alternative with better security.
#
# Required specialArgs:
#   users - User data attrset (see lib/schema.nix for schema)
#
# Note: This module is NOT imported on WSL configurations because WSL uses
# Docker Desktop on the Windows host. See hosts/devbox-wsl/default.nix.
#
# Note: This module conflicts with nixos/docker.nix when dockerCompat is enabled.
# Do not import both modules on the same host configuration.

{
  config,
  lib,
  users,
  ...
}:

let
  cfg = config.devbox.podman;
in
{
  # ─────────────────────────────────────────────────────────────────────────────
  # Module Options
  # ─────────────────────────────────────────────────────────────────────────────

  options.devbox.podman = {
    enable = lib.mkEnableOption "Podman rootless container runtime";

    dockerCompat = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Enable Docker CLI compatibility.
        Creates a 'docker' alias that points to podman.
        WARNING: Do not enable this if Docker is also installed.
      '';
    };

    enableDns = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Enable DNS for the default podman network.
        Required for containers to communicate via hostname in podman-compose.
      '';
    };
  };

  # ─────────────────────────────────────────────────────────────────────────────
  # Module Configuration
  # ─────────────────────────────────────────────────────────────────────────────

  config = lib.mkIf cfg.enable {
    # ───────────────────────────────────────────────────────────────────────────
    # Podman Configuration
    # ───────────────────────────────────────────────────────────────────────────

    virtualisation = {
      # Enable container support (required for Podman)
      containers.enable = true;

      podman = {
        enable = true;

        # Docker CLI compatibility (creates 'docker' alias)
        inherit (cfg) dockerCompat;

        # Enable DNS for container networking
        # Required for podman-compose containers to communicate
        defaultNetwork.settings.dns_enabled = cfg.enableDns;
      };
    };

    # ───────────────────────────────────────────────────────────────────────────
    # Rootless Container Support
    # ───────────────────────────────────────────────────────────────────────────
    # Rootless containers require subuid/subgid ranges for user namespace mapping.
    # This allows unprivileged users to run containers without root access.
    #
    # IMPORTANT: Each user must have a unique, non-overlapping range to prevent
    # permission conflicts and security issues between users' containers.
    # Range calculation: base (100000) + (user_index * 65536)

    users.users = lib.listToAttrs (
      lib.imap0 (idx: name: {
        inherit name;
        value = {
          subUidRanges = [
            {
              startUid = 100000 + (idx * 65536);
              count = 65536;
            }
          ];
          subGidRanges = [
            {
              startGid = 100000 + (idx * 65536);
              count = 65536;
            }
          ];
        };
      }) users.allUserNames
    );

    # ───────────────────────────────────────────────────────────────────────────
    # Safety Assertions
    # ───────────────────────────────────────────────────────────────────────────

    assertions = [
      {
        assertion = !(cfg.enable && cfg.dockerCompat && config.virtualisation.docker.enable);
        message = ''
          Cannot enable both Podman (with dockerCompat) and Docker.
          This would create conflicting 'docker' commands.

          Options:
          1. Disable Docker: Remove nixos/docker.nix from your host imports
          2. Disable dockerCompat: Set devbox.podman.dockerCompat = false

          For WSL configurations, use Docker Desktop on Windows host instead.
        '';
      }
    ];
  };
}
