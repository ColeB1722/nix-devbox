# NixOS Orchestrator Cleanup Module - Idle Container Management
#
# This module provides automated lifecycle management for dev containers:
#   - Auto-stop containers after configurable days of idle activity
#   - Auto-destroy containers after configurable days in stopped state
#   - Daily cleanup timer via systemd
#
# The cleanup process checks container activity timestamps and applies
# lifecycle rules defined in users.nix containers configuration.
#
# Usage:
#   In your host configuration (automatically imported with orchestrator.nix):
#     devbox.orchestrator.cleanup.enable = true;
#
# Constitution alignment:
#   - Principle I: Declarative Configuration (all config in Nix)
#   - Principle II: Headless-First Design (automated, no manual intervention)
#   - Principle IV: Modular and Reusable (standalone module)

{
  config,
  lib,
  pkgs,
  users ? { },
  ...
}:

let
  cfg = config.devbox.orchestrator.cleanup;

  # Container configuration from users.nix (with defaults)
  containersConfig = users.containers or { };
  idleStopDays = containersConfig.idleStopDays or 7;
  stoppedDestroyDays = containersConfig.stoppedDestroyDays or 14;

  # Cleanup script
  cleanupScript = pkgs.writeShellScript "devbox-cleanup" ''
    set -euo pipefail

    # Configuration
    IDLE_STOP_DAYS="${toString idleStopDays}"
    STOPPED_DESTROY_DAYS="${toString stoppedDestroyDays}"
    REGISTRY_DIR="/var/lib/devbox"
    LOG_TAG="devbox-cleanup"

    # Logging
    log_info() {
      logger -t "$LOG_TAG" -p user.info "$*"
      echo "[INFO] $*"
    }

    log_warn() {
      logger -t "$LOG_TAG" -p user.warning "$*"
      echo "[WARN] $*" >&2
    }

    log_error() {
      logger -t "$LOG_TAG" -p user.error "$*"
      echo "[ERROR] $*" >&2
    }

    # Calculate days since a timestamp
    days_since() {
      local timestamp="$1"
      local now
      local then
      local diff

      now=$(date +%s)
      # Handle ISO 8601 format
      then=$(date -d "$timestamp" +%s 2>/dev/null || echo "0")

      if [[ "$then" == "0" ]]; then
        echo "999"  # Invalid timestamp, return large number
        return
      fi

      # Handle clock skew - if timestamp is in the future, treat as just active
      diff=$(( now - then ))
      if [[ "$diff" -lt 0 ]]; then
        echo "0"
        return
      fi

      echo $(( diff / 86400 ))
    }

    # Process containers for each user
    process_user_containers() {
      local user="$1"
      local user_data_dir="/home/$user/.local/share/devbox"
      local registry="$user_data_dir/containers.json"

      if [[ ! -f "$registry" ]]; then
        log_info "No registry found for user $user, skipping"
        return
      fi

      log_info "Processing containers for user: $user"

      # Get containers from registry
      local containers
      containers=$(${pkgs.jq}/bin/jq -c '.containers[]' "$registry" 2>/dev/null || echo "")

      if [[ -z "$containers" ]]; then
        log_info "No containers found for user $user"
        return
      fi

      echo "$containers" | while read -r container; do
        local name state last_activity
        name=$(echo "$container" | ${pkgs.jq}/bin/jq -r '.name')
        state=$(echo "$container" | ${pkgs.jq}/bin/jq -r '.state')
        last_activity=$(echo "$container" | ${pkgs.jq}/bin/jq -r '.lastActivityAt')

        local days_idle
        days_idle=$(days_since "$last_activity")

        log_info "Container '$name': state=$state, idle_days=$days_idle"

        # Check for auto-stop (running containers idle too long)
        if [[ "$state" == "running" && "$days_idle" -ge "$IDLE_STOP_DAYS" ]]; then
          log_warn "Container '$name' idle for $days_idle days (limit: $IDLE_STOP_DAYS), stopping..."

          # TODO: Send notification to user before stopping
          # For now, just log the action

          # Stop the container using Podman
          if sudo -u "$user" ${pkgs.podman}/bin/podman stop "$name" 2>/dev/null; then
            log_info "Container '$name' stopped successfully"

            # Update registry state with exclusive file lock to prevent race conditions
            (
              ${pkgs.flock}/bin/flock -x 200
              local tmp_file
              tmp_file=$(mktemp)
              ${pkgs.jq}/bin/jq --arg name "$name" \
                '(.containers[] | select(.name == $name)).state = "stopped"' \
                "$registry" > "$tmp_file"
              mv "$tmp_file" "$registry"
              chown "$user:$user" "$registry"
            ) 200>"$registry.lock"
          else
            log_error "Failed to stop container '$name'"
          fi
        fi

        # Check for auto-destroy (stopped containers too long)
        if [[ "$state" == "stopped" && "$days_idle" -ge "$STOPPED_DESTROY_DAYS" ]]; then
          log_warn "Container '$name' stopped for $days_idle days (limit: $STOPPED_DESTROY_DAYS), destroying..."

          # TODO: Send notification to user before destroying
          # For now, just log the action

          # Remove the container
          if sudo -u "$user" ${pkgs.podman}/bin/podman rm -f "$name" 2>/dev/null; then
            log_info "Container '$name' removed successfully"

            # Remove volume (data loss warning already logged)
            local volume_name="''${name}-data"
            if sudo -u "$user" ${pkgs.podman}/bin/podman volume rm "$volume_name" 2>/dev/null; then
              log_info "Volume '$volume_name' removed"
            fi

            # Update registry with exclusive file lock to prevent race conditions
            (
              ${pkgs.flock}/bin/flock -x 200
              local tmp_file
              tmp_file=$(mktemp)
              ${pkgs.jq}/bin/jq --arg name "$name" \
                '.containers |= map(select(.name != $name))' \
                "$registry" > "$tmp_file"
              mv "$tmp_file" "$registry"
              chown "$user:$user" "$registry"
            ) 200>"$registry.lock"

            # Remove from Tailscale (best effort)
            # Note: Ephemeral auth keys auto-remove the device when disconnected,
            # so explicit logout is not needed. The tailscale logout command does
            # not support --hostname flag. If manual removal is needed, use the
            # Tailscale admin API instead.
            log_info "Container '$name' used ephemeral key - Tailscale device will auto-remove"

            log_info "Container '$name' destroyed and removed from registry"
          else
            log_error "Failed to destroy container '$name'"
          fi
        fi
      done
    }

    # Main cleanup routine
    main() {
      log_info "Starting devbox cleanup (idle_stop=$IDLE_STOP_DAYS days, stopped_destroy=$STOPPED_DESTROY_DAYS days)"

      # Get all users with home directories
      local users
      users=$(getent passwd | awk -F: '$6 ~ /^\/home\// {print $1}')

      for user in $users; do
        process_user_containers "$user"
      done

      log_info "Devbox cleanup completed"
    }

    main "$@"
  '';
in
{
  options.devbox.orchestrator.cleanup = {
    enable = lib.mkEnableOption "dev container cleanup timer";

    calendar = lib.mkOption {
      type = lib.types.str;
      default = "daily";
      description = "Systemd calendar expression for when to run cleanup";
      example = "*-*-* 03:00:00";
    };

    persistent = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to run missed cleanup runs on boot";
    };
  };

  config = lib.mkIf cfg.enable {
    # ─────────────────────────────────────────────────────────────────────────
    # Cleanup Service
    # ─────────────────────────────────────────────────────────────────────────
    # Systemd service that performs the actual cleanup

    systemd.services.devbox-cleanup = {
      description = "Dev container lifecycle cleanup";
      path = with pkgs; [
        coreutils
        podman
        jq
        tailscale
        util-linux # for logger
      ];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${cleanupScript}";

        # Security hardening
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = "read-only";
        PrivateTmp = true;

        # Allow access to user home directories for registry
        ReadWritePaths = [
          "/home"
          "/var/lib/devbox"
        ];

        # Logging
        StandardOutput = "journal";
        StandardError = "journal";
        SyslogIdentifier = "devbox-cleanup";
      };
    };

    # ─────────────────────────────────────────────────────────────────────────
    # Cleanup Timer
    # ─────────────────────────────────────────────────────────────────────────
    # Systemd timer that triggers cleanup on schedule

    systemd.timers.devbox-cleanup = {
      description = "Timer for dev container lifecycle cleanup";
      wantedBy = [ "timers.target" ];

      timerConfig = {
        OnCalendar = cfg.calendar;
        Persistent = cfg.persistent;

        # Randomize start time slightly to avoid thundering herd
        RandomizedDelaySec = "5min";

        # Accuracy - cleanup doesn't need to be precise
        AccuracySec = "1h";
      };
    };

    # ─────────────────────────────────────────────────────────────────────────
    # Manual Trigger Script
    # ─────────────────────────────────────────────────────────────────────────
    # Allow admins to manually trigger cleanup

    environment.systemPackages = [
      (pkgs.writeShellScriptBin "devbox-cleanup-now" ''
        echo "Triggering devbox cleanup..."
        sudo systemctl start devbox-cleanup.service
        echo "Check status with: journalctl -u devbox-cleanup -f"
      '')
    ];
  };
}
