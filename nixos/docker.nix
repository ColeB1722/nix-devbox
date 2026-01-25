# NixOS Docker Module - Container Runtime Configuration
#
# Enables Docker for container-based development workflows.
# Users in the 'docker' group can run containers without sudo.
#
# Constitution alignment:
#   - Principle I: Declarative Configuration (Docker in Nix)
#   - Principle II: Headless-First Design (CLI-based container management)
#   - Principle IV: Modular and Reusable (separate docker module)
#   - Principle V: Documentation as Code (inline comments)
#
# Note: This module is NOT imported on WSL configurations because WSL uses
# Docker Desktop on the Windows host. See hosts/devbox-wsl/default.nix.

{ config, ... }:

{
  # ─────────────────────────────────────────────────────────────────────────────
  # Docker Configuration
  # ─────────────────────────────────────────────────────────────────────────────

  virtualisation.docker = {
    # Enable Docker daemon
    enable = true;

    # Start Docker on boot
    enableOnBoot = true;

    # Automatic cleanup of unused images and containers
    autoPrune = {
      enable = true;
      dates = "weekly";
      flags = [ "--all" ];
    };
  };

  # ─────────────────────────────────────────────────────────────────────────────
  # Security Assertions
  # ─────────────────────────────────────────────────────────────────────────────
  # Ensure all dev users are in the docker group to avoid permission issues.
  # This assertion helps catch misconfiguration early.

  assertions = [
    {
      assertion = builtins.elem "docker" (config.users.users.coal.extraGroups or [ ]);
      message = ''
        Docker module requires user 'coal' to be in the 'docker' group.
        Add "docker" to users.users.coal.extraGroups in nixos/users.nix
      '';
    }
    {
      assertion = builtins.elem "docker" (config.users.users.violino.extraGroups or [ ]);
      message = ''
        Docker module requires user 'violino' to be in the 'docker' group.
        Add "docker" to users.users.violino.extraGroups in nixos/users.nix
      '';
    }
  ];

  # ─────────────────────────────────────────────────────────────────────────────
  # Firewall Configuration
  # ─────────────────────────────────────────────────────────────────────────────
  # Docker manages its own iptables rules for container networking.
  # No additional firewall configuration needed for basic container usage.

  # Note: If you need to expose container ports externally, use:
  # networking.firewall.allowedTCPPorts = [ <port> ];
}
