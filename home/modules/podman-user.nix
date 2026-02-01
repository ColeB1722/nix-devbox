# Home Manager Podman User Module - User-Level Container Configuration
#
# This module provides user-level Podman configuration for rootless container
# management. It handles socket activation, XDG paths, and first-login initialization.
#
# System-level Podman enablement is in nixos/podman-isolation.nix; this handles
# the user experience (socket activation, storage paths, initialization).
#
# Constitution alignment:
#   - Principle I: Declarative Configuration (user container config in Nix)
#   - Principle II: Headless-First Design (CLI container management)
#   - Principle IV: Modular and Reusable (separate user-level module)
#   - Principle V: Documentation as Code (inline comments)
#
# Features:
#   - Podman socket activation for API access
#   - Automatic initialization on first login
#   - XDG-compliant storage paths
#   - Systemd user service management

{ config, pkgs, ... }:

{
  # ─────────────────────────────────────────────────────────────────────────────
  # XDG Configuration
  # ─────────────────────────────────────────────────────────────────────────────
  # Ensure Podman uses XDG-compliant paths for container storage

  xdg.enable = true;

  # ─────────────────────────────────────────────────────────────────────────────
  # Home Manager Configuration (consolidated)
  # ─────────────────────────────────────────────────────────────────────────────

  home = {
    # ─────────────────────────────────────────────────────────────────────────
    # Podman Configuration Files
    # ─────────────────────────────────────────────────────────────────────────

    file = {
      # Note: runroot is intentionally not set here - Podman will use
      # $XDG_RUNTIME_DIR/containers by default, which is correct for rootless.
      # Setting runroot explicitly would require home.uid which may not be set.
      ".config/containers/storage.conf".text = ''
        [storage]
        driver = "overlay"
        graphroot = "${config.home.homeDirectory}/.local/share/containers/storage"

        [storage.options]
        mount_program = "${pkgs.fuse-overlayfs}/bin/fuse-overlayfs"

        [storage.options.overlay]
        mount_program = "${pkgs.fuse-overlayfs}/bin/fuse-overlayfs"
      '';

      # User-level containers.conf for Podman behavior
      ".config/containers/containers.conf".text = ''
        [containers]
        # Use host network by default for simpler networking in dev containers
        # Change to "private" for isolated networking
        netns = "private"

        # Default timezone from host
        tz = "local"

        # Default ulimits for containers
        default_ulimits = [
          "nofile=65536:65536",
        ]

        [engine]
        # Use systemd cgroup manager for proper resource limiting
        cgroup_manager = "systemd"

        # Enable events logging to journald for container lifecycle tracking
        events_logger = "journald"

        # Runtime is crun (better rootless support)
        runtime = "crun"

        [network]
        # Use pasta for rootless networking (faster than slirp4netns)
        default_network = "podman"
        network_backend = "netavark"
      '';

      # Registries configuration (default to Docker Hub and common registries)
      ".config/containers/registries.conf".text = ''
        [registries.search]
        registries = ['docker.io', 'quay.io', 'ghcr.io']

        [registries.insecure]
        registries = []

        [registries.block]
        registries = []
      '';
    };

    # ─────────────────────────────────────────────────────────────────────────
    # Environment Variables
    # ─────────────────────────────────────────────────────────────────────────

    sessionVariables = {
      # Point to user's Podman socket for API tools
      DOCKER_HOST = "unix://$XDG_RUNTIME_DIR/podman/podman.sock";

      # Disable Docker CLI plugins warning when using Podman
      DOCKER_CLI_HINTS = "false";
    };

    # ─────────────────────────────────────────────────────────────────────────
    # Packages
    # ─────────────────────────────────────────────────────────────────────────

    packages = with pkgs; [
      podman-compose # Docker Compose compatibility
      dive # Explore container image layers
    ];
  };

  # ─────────────────────────────────────────────────────────────────────────────
  # Systemd User Services
  # ─────────────────────────────────────────────────────────────────────────────

  systemd.user = {
    # Podman socket for API access (used by tools like podman-compose)
    sockets.podman = {
      Unit = {
        Description = "Podman API Socket";
        Documentation = "man:podman-system-service(1)";
      };

      Socket = {
        ListenStream = "%t/podman/podman.sock";
        SocketMode = "0660";
      };

      Install = {
        WantedBy = [ "sockets.target" ];
      };
    };

    services = {
      # Podman API service (socket-activated)
      podman = {
        Unit = {
          Description = "Podman API Service";
          Documentation = "man:podman-system-service(1)";
          Requires = [ "podman.socket" ];
          After = [ "podman.socket" ];
        };

        Service = {
          Type = "exec";
          ExecStart = "${pkgs.podman}/bin/podman system service --time=0";
          Restart = "on-failure";
          RestartSec = "5s";
        };
      };

      # Podman initialization service (runs once on first login)
      podman-init = {
        Unit = {
          Description = "Initialize Podman for user";
          Documentation = "man:podman-system-migrate(1)";
          # Only run once per session
          ConditionPathExists = "!%h/.local/share/containers/.initialized";
        };

        Service = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = pkgs.writeShellScript "podman-init" ''
            set -e

            # Create containers directory structure
            mkdir -p "$HOME/.local/share/containers/storage"
            mkdir -p "$HOME/.config/containers"

            # Run Podman system migrate to initialize storage
            ${pkgs.podman}/bin/podman system migrate 2>/dev/null || true

            # Pull a test image to verify everything works
            # This is optional and commented out to avoid network dependency
            # ${pkgs.podman}/bin/podman pull docker.io/library/hello-world:latest

            # Mark as initialized
            touch "$HOME/.local/share/containers/.initialized"

            echo "Podman initialized successfully for $USER"
          '';
        };

        Install = {
          WantedBy = [ "default.target" ];
        };
      };

      # Container auto-update service
      podman-auto-update = {
        Unit = {
          Description = "Podman auto-update service";
          Documentation = "man:podman-auto-update(1)";
        };

        Service = {
          Type = "oneshot";
          ExecStart = "${pkgs.podman}/bin/podman auto-update";
        };
      };
    };

    # Container auto-update timer (optional, for production containers)
    timers.podman-auto-update = {
      Unit = {
        Description = "Podman auto-update timer";
      };

      Timer = {
        OnCalendar = "daily";
        Persistent = true;
        RandomizedDelaySec = "900";
      };

      Install = {
        WantedBy = [ "timers.target" ];
      };
    };
  };

  # ─────────────────────────────────────────────────────────────────────────────
  # Shell Integration
  # ─────────────────────────────────────────────────────────────────────────────

  programs = {
    fish.shellAbbrs = {
      # Podman shortcuts
      p = "podman";
      pps = "podman ps";
      ppsa = "podman ps -a";
      pimg = "podman images";
      prun = "podman run -it --rm";
      prm = "podman rm";
      prmi = "podman rmi";
      plogs = "podman logs -f";
      pexec = "podman exec -it";
      pstop = "podman stop";
      pstart = "podman start";
      pbuild = "podman build";
      pcompose = "podman-compose";
    };

    bash.shellAliases = {
      p = "podman";
      pps = "podman ps";
      ppsa = "podman ps -a";
      pimg = "podman images";
    };
  };
}
