# NixOS Orchestrator Module - Container Management for Dev Containers
#
# This module configures a NixOS host as a dev container orchestrator.
# It provides:
#   - Podman for rootless container management
#   - devbox-ctl CLI for container lifecycle operations
#   - 1Password CLI for secure secret retrieval
#   - Git and GitHub CLI for repository management
#
# The orchestrator hosts dev containers that are accessible via Tailscale SSH.
# Containers are isolated per-user with resource limits and lifecycle automation.
#
# Usage:
#   In your host configuration:
#     imports = [ ./nixos/orchestrator.nix ];
#
# Prerequisites:
#   - Tailscale module enabled (for orchestrator access)
#   - SSH module enabled (for key-based authentication)
#   - Firewall module enabled (for security)
#
# Constitution alignment:
#   - Principle I: Declarative Configuration (all config in Nix)
#   - Principle II: Headless-First Design (CLI-only, no GUI)
#   - Principle III: Security by Default (rootless containers, SSH keys only)
#   - Principle IV: Modular and Reusable (standalone module)

{
  config,
  lib,
  pkgs,
  users ? { },
  ...
}:

let
  cfg = config.devbox.orchestrator;

  # Container configuration from users.nix (with defaults)
  containersConfig = users.containers or { };
  opVault = containersConfig.opVault or "DevBox";
  maxPerUser = containersConfig.maxPerUser or 5;
  maxGlobal = containersConfig.maxGlobal or 7;
  defaultCpu = containersConfig.defaultCpu or 2;
  defaultMemory = containersConfig.defaultMemory or "4G";
  idleStopDays = containersConfig.idleStopDays or 7;
  stoppedDestroyDays = containersConfig.stoppedDestroyDays or 14;

  # devbox-ctl Python CLI package
  devbox-ctl = pkgs.callPackage ../scripts/devbox-ctl/package.nix { };
in
{
  options.devbox.orchestrator = {
    enable = lib.mkEnableOption "dev container orchestrator";

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/devbox";
      description = "Directory for orchestrator data (container registry, etc.)";
    };
  };

  config = lib.mkIf cfg.enable {
    # ─────────────────────────────────────────────────────────────────────────
    # NixOS Assertions for Security
    # ─────────────────────────────────────────────────────────────────────────
    # These assertions ensure the orchestrator meets security requirements

    assertions = [
      {
        assertion = config.networking.firewall.enable;
        message = "Orchestrator requires firewall to be enabled (networking.firewall.enable = true)";
      }
      {
        # Explicit `== false` required: `!null` throws an error, but `null == false` returns false
        assertion = config.services.openssh.settings.PasswordAuthentication == false;
        message = "Orchestrator requires SSH password authentication to be explicitly disabled";
      }
      {
        # Accept both "no" (fully disabled) and "prohibit-password" (key-only, useful for automation)
        assertion = builtins.elem config.services.openssh.settings.PermitRootLogin [
          "no"
          "prohibit-password"
        ];
        message = "Orchestrator requires SSH root login to be disabled or set to prohibit-password";
      }
    ];

    # ─────────────────────────────────────────────────────────────────────────
    # Podman Configuration
    # ─────────────────────────────────────────────────────────────────────────
    # Rootless Podman for secure container management

    virtualisation.podman = {
      enable = true;

      # Enable Docker compatibility (docker CLI commands work with Podman)
      dockerCompat = true;

      # Default policy for pulling images
      defaultNetwork.settings = {
        dns_enabled = true;
      };

      # Auto-prune unused images and containers
      autoPrune = {
        enable = true;
        dates = "weekly";
        flags = [ "--all" ];
      };
    };

    # Enable container networking
    virtualisation.containers.enable = true;

    # ─────────────────────────────────────────────────────────────────────────
    # System Packages
    # ─────────────────────────────────────────────────────────────────────────
    # Tools required for orchestrator operation

    environment.systemPackages = with pkgs; [
      # ─── devbox-ctl CLI ───
      devbox-ctl

      # ─── Container Management ───
      podman
      podman-compose
      skopeo # Container image operations
      buildah # Container image building

      # ─── Repository Management ───
      git
      gh # GitHub CLI

      # ─── Secrets Management ───
      _1password # 1Password CLI (op command)

      # ─── Utilities ───
      jq # JSON processing
      curl
      wget

      # ─── Monitoring ───
      htop
      btop
    ];

    # ─────────────────────────────────────────────────────────────────────────
    # Environment Variables for devbox-ctl
    # ─────────────────────────────────────────────────────────────────────────
    # Configure devbox-ctl defaults from users.nix containers config

    environment.variables = {
      DEVBOX_OP_VAULT = opVault;
      DEVBOX_MAX_PER_USER = toString maxPerUser;
      DEVBOX_MAX_GLOBAL = toString maxGlobal;
      DEVBOX_DEFAULT_CPU = toString defaultCpu;
      DEVBOX_DEFAULT_MEMORY = defaultMemory;
      DEVBOX_IDLE_STOP_DAYS = toString idleStopDays;
      DEVBOX_STOPPED_DESTROY_DAYS = toString stoppedDestroyDays;
    };

    # ─────────────────────────────────────────────────────────────────────────
    # Data Directory Setup & User Lingering
    # ─────────────────────────────────────────────────────────────────────────
    # Create orchestrator data directory and enable lingering for user services

    systemd.tmpfiles.rules =
      let
        allUsers = users.allUserNames or [ ];
        # Lingering files so user services (Podman containers) persist after logout
        lingerRules = map (user: "f /var/lib/systemd/linger/${user} 0644 root root -") allUsers;
      in
      [
        # Data directories for container registry
        "d ${cfg.dataDir} 0755 root root -"
        "d ${cfg.dataDir}/containers 0755 root root -"
      ]
      ++ lingerRules;

    # ─────────────────────────────────────────────────────────────────────────
    # User Configuration for Podman
    # ─────────────────────────────────────────────────────────────────────────
    # Allow users to run rootless Podman

    users.groups.podman = { };

    # Subuid/subgid ranges for rootless containers
    # Each user needs a range of subordinate UIDs/GIDs for user namespaces
    users.users =
      let
        # Get all user names from users.nix
        allUsers = users.allUserNames or [ ];

        # Generate subuid/subgid config for each user
        # Each user gets 65536 subordinate IDs starting at 100000 + (index * 65536)
        mkUserConfig =
          idx: name:
          lib.nameValuePair name {
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
            extraGroups = [ "podman" ];
          };
      in
      builtins.listToAttrs (lib.imap0 mkUserConfig allUsers);

    # ─────────────────────────────────────────────────────────────────────────
    # Kernel Parameters for Containers
    # ─────────────────────────────────────────────────────────────────────────
    # Optimize kernel settings for container workloads

    boot.kernel.sysctl = {
      # Allow more user namespaces for rootless containers
      "user.max_user_namespaces" = 28633;

      # Increase inotify limits for file watching in containers
      "fs.inotify.max_user_watches" = 524288;
      "fs.inotify.max_user_instances" = 512;

      # Network settings for container traffic
      "net.ipv4.ip_forward" = 1;
    };

  };
}
