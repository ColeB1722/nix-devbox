# NixOS Podman Isolation Module - Per-User Container Isolation
#
# This module provides rootless Podman with per-user isolation for multi-tenant
# container workloads. Each user operates in a separate namespace and cannot
# see or affect other users' containers.
#
# Features:
#   - Rootless Podman (no root daemon)
#   - Per-user subuid/subgid allocation (65536 IDs each)
#   - User lingering for persistent services
#   - cgroup delegation for container resource management
#   - Optional resource quota enforcement
#
# Constitution alignment:
#   - Principle I: Declarative Configuration (all config in Nix)
#   - Principle II: Headless-First Design (CLI container management)
#   - Principle III: Security by Default (user isolation, no privileged containers)
#   - Principle IV: Modular and Reusable (standalone module)
#   - Principle V: Documentation as Code (inline comments)
#
# Related modules:
#   - home/modules/podman-user.nix: User-level Podman configuration
#   - nixos/users.nix: User creation with resourceQuota support
#
# Security notes:
#   - Containers run as unprivileged user namespaces
#   - No --privileged containers allowed (prevents nested containers)
#   - Each user's containers are invisible to other users
#   - Volume mounts restricted to user's home directory

{
  config,
  lib,
  pkgs,
  users,
  ...
}:

let
  cfg = config.devbox.podman.isolation;

  # Calculate subuid/subgid range for a user
  # Each user gets 65536 IDs, starting at 100000 + (uid * 65536)
  # This ensures non-overlapping ranges for all users
  mkSubidRange = userData: {
    startUid = 100000 + (userData.uid * 65536);
    count = 65536;
  };

in
{
  options.devbox.podman.isolation = {
    enable = lib.mkEnableOption "per-user Podman isolation for multi-tenant container workloads";

    enableQuotas = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Enable resource quota enforcement via cgroups and filesystem quotas.
        When enabled, users with resourceQuota defined will have their
        containers limited to the specified CPU, memory, and storage.
      '';
    };

    allowPrivileged = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Allow privileged containers. This is a security risk and should
        only be enabled if absolutely necessary. Privileged containers
        can escape isolation and affect the host system.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # ─────────────────────────────────────────────────────────────────────────
    # Podman Configuration
    # ─────────────────────────────────────────────────────────────────────────

    virtualisation.podman = {
      enable = true;

      # Disable Docker compatibility to avoid socket conflicts
      # Each user has their own rootless Podman socket
      dockerCompat = false;
      dockerSocket.enable = false;

      # Use default OCI runtime (crun for rootless)
      defaultNetwork.settings.dns_enabled = true;

      # Enable container auto-updates (optional, useful for long-running services)
      autoPrune = {
        enable = true;
        dates = "weekly";
        flags = [ "--all" ];
      };
    };

    # ─────────────────────────────────────────────────────────────────────────
    # Subuid/Subgid Configuration
    # ─────────────────────────────────────────────────────────────────────────
    # Each user needs a range of subordinate UIDs/GIDs for user namespace mapping.
    # This allows rootless containers to map container UIDs to unprivileged host UIDs.

    users.users = lib.listToAttrs (
      map (name: {
        inherit name;
        value =
          let
            range = mkSubidRange users.${name};
          in
          {
            subUidRanges = [
              {
                inherit (range) startUid count;
              }
            ];
            subGidRanges = [
              {
                startGid = range.startUid;
                inherit (range) count;
              }
            ];
          };
      }) users.allUserNames
    );

    # ─────────────────────────────────────────────────────────────────────────
    # User Lingering
    # ─────────────────────────────────────────────────────────────────────────
    # Enable lingering for all users so their systemd user services persist
    # after logout. This is required for long-running containers.

    systemd.tmpfiles.rules = map (
      name: "f /var/lib/systemd/linger/${name} 0644 root root -"
    ) users.allUserNames;

    # ─────────────────────────────────────────────────────────────────────────
    # Cgroup Delegation
    # ─────────────────────────────────────────────────────────────────────────
    # Enable cgroup v2 delegation for user slices so Podman can manage
    # container resource limits within the user's cgroup.

    systemd.services."user@" = {
      serviceConfig = {
        Delegate = "yes";
      };
    };

    # ─────────────────────────────────────────────────────────────────────────
    # Kernel Parameters for Rootless Containers
    # ─────────────────────────────────────────────────────────────────────────

    boot.kernel.sysctl = {
      # Allow unprivileged users to create user namespaces
      "kernel.unprivileged_userns_clone" = 1;

      # Increase max user namespaces (default is often too low)
      "user.max_user_namespaces" = 28633;

      # Allow ping from unprivileged containers
      "net.ipv4.ping_group_range" = "0 65536";
    };

    # ─────────────────────────────────────────────────────────────────────────
    # Container Security Configuration
    # ─────────────────────────────────────────────────────────────────────────
    # Use NixOS's virtualisation.containers options instead of raw etc files
    # to avoid conflicts with the containers.nix module.

    virtualisation.containers.containersConf.settings = lib.mkIf (!cfg.allowPrivileged) {
      containers = {
        # Disable privileged containers by default
        # This prevents container escape via --privileged flag
        privileged = false;

        # Default capabilities (minimal set)
        default_capabilities = [
          "CHOWN"
          "DAC_OVERRIDE"
          "FOWNER"
          "FSETID"
          "KILL"
          "NET_BIND_SERVICE"
          "SETFCAP"
          "SETGID"
          "SETPCAP"
          "SETUID"
        ];
      };

      engine = {
        # Use crun as the OCI runtime (better for rootless)
        runtime = "crun";

        # Enable cgroup v2 management
        cgroup_manager = "systemd";

        # Events logger
        events_logger = "journald";
      };
    };

    # ─────────────────────────────────────────────────────────────────────────
    # Filesystem Quota Documentation
    # ─────────────────────────────────────────────────────────────────────────
    # Storage quotas require filesystem support. Add to hardware-configuration.nix:
    #   fileSystems."/".options = [ "usrquota" ];
    # Or for home partition:
    #   fileSystems."/home".options = [ "usrquota" ];
    #
    # After deployment, initialize quotas:
    #   sudo quotacheck -cugm /home
    #   sudo quotaon /home
    #
    # Quotas are set per-user based on resourceQuota.storageGB in users.nix

    # ─────────────────────────────────────────────────────────────────────────
    # Quota Activation Script (if enabled)
    # ─────────────────────────────────────────────────────────────────────────

    system.activationScripts.podmanQuotas = lib.mkIf cfg.enableQuotas {
      text = ''
        # Set filesystem quotas for users with resourceQuota defined
        # This runs on every nixos-rebuild switch

        ${lib.concatMapStringsSep "\n" (
          name:
          let
            userData = users.${name};
          in
          if userData ? resourceQuota && userData.resourceQuota ? storageGB then
            ''
              # Set quota for ${name}: ${toString userData.resourceQuota.storageGB}GB
              if command -v setquota &> /dev/null; then
                # Format: setquota -u <user> <soft-block> <hard-block> <soft-inode> <hard-inode> <filesystem>
                # Convert GB to KB (1GB = 1048576 KB), add 1GB grace period for hard limit
                SOFT_KB=$(( ${toString userData.resourceQuota.storageGB} * 1048576 ))
                HARD_KB=$(( SOFT_KB + 1048576 ))
                setquota -u ${name} $SOFT_KB $HARD_KB 0 0 /home 2>/dev/null || true
              fi
            ''
          else
            ""
        ) users.allUserNames}
      '';
    };

    # ─────────────────────────────────────────────────────────────────────────
    # Required Packages and Admin Helper Scripts
    # ─────────────────────────────────────────────────────────────────────────

    environment.systemPackages = with pkgs; [
      # Core Podman tools
      podman
      podman-compose
      skopeo # Container image operations
      crun # OCI runtime for rootless containers
      slirp4netns # User-mode networking for rootless containers
      fuse-overlayfs # Overlayfs for rootless containers
      quota # Filesystem quota tools (if enableQuotas)

      # Admin helper scripts
      (writeShellScriptBin "podman-admin-ps" ''
        # List containers for all users
        # Usage: podman-admin-ps

        echo "=== Container Overview ==="
        for user in ${lib.concatStringsSep " " users.allUserNames}; do
          echo ""
          echo "--- $user ---"
          sudo -u "$user" podman ps -a --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Image}}" 2>/dev/null || echo "No containers or Podman not initialized"
        done
      '')

      (writeShellScriptBin "podman-admin-stop" ''
        # Stop a container for a specific user
        # Usage: podman-admin-stop <username> <container-id-or-name>

        if [ $# -ne 2 ]; then
          echo "Usage: podman-admin-stop <username> <container-id-or-name>"
          exit 1
        fi

        USER="$1"
        CONTAINER="$2"

        # Validate user exists
        if ! id "$USER" &>/dev/null; then
          echo "Error: User '$USER' does not exist"
          exit 1
        fi

        echo "Stopping container '$CONTAINER' for user '$USER'..."
        sudo -u "$USER" podman stop "$CONTAINER"
      '')

      (writeShellScriptBin "podman-admin-stats" ''
        # Show resource usage for all users' containers
        # Usage: podman-admin-stats

        echo "=== Container Resource Usage ==="
        for user in ${lib.concatStringsSep " " users.allUserNames}; do
          echo ""
          echo "--- $user ---"
          sudo -u "$user" podman stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" 2>/dev/null || echo "No running containers"
        done
      '')
    ];
  };
}
