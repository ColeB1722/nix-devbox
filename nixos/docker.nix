# NixOS Docker Module - Container Runtime Configuration
#
# Enables Docker for container-based development workflows.
# Users in the 'docker' group can run containers without sudo.
#
# Constitution alignment:
#   - Principle I: Declarative Configuration (Docker in Nix)
#   - Principle II: Headless-First Design (CLI-based container management)
#   - Principle IV: Modular and Reusable (accepts user data from consumer)
#   - Principle V: Documentation as Code (inline comments)
#
# Required specialArgs:
#   users - User data attrset (see lib/schema.nix for schema)
#
# Note: This module is NOT imported on WSL configurations because WSL uses
# Docker Desktop on the Windows host. See hosts/devbox-wsl/default.nix.

{
  config,
  users,
  ...
}:

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
  # Ensure all users are in the docker group to avoid permission issues.
  # This assertion helps catch misconfiguration early.
  # The users.nix module automatically adds "docker" to all users' extraGroups.

  assertions = map (name: {
    assertion = builtins.elem "docker" (config.users.users.${name}.extraGroups or [ ]);
    message = ''
      Docker module requires user '${name}' to be in the 'docker' group.
      This should be automatic via nixos/users.nix - check your configuration.
    '';
  }) users.allUserNames;

  # ─────────────────────────────────────────────────────────────────────────────
  # Firewall Configuration
  # ─────────────────────────────────────────────────────────────────────────────
  # Docker manages its own iptables rules for container networking.
  # No additional firewall configuration needed for basic container usage.

  # Note: If you need to expose container ports externally, use:
  # networking.firewall.allowedTCPPorts = [ <port> ];
}
