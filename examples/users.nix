# Example User Data for CI and Testing
#
# This file provides placeholder user data that allows the public flake
# to build and test without requiring personal information.
#
# For your own configuration, copy this to your private repo and replace
# with your actual user data. See docs/USER-DATA-SCHEMA.md for details.
#
# IMPORTANT: This is example data only - do NOT use these SSH keys
# in production. Generate your own with: ssh-keygen -t ed25519

{
  # ─────────────────────────────────────────────────────────────────────────────
  # exampleuser - Example Administrator
  # ─────────────────────────────────────────────────────────────────────────────
  exampleuser = {
    name = "exampleuser";
    uid = 1000;
    description = "Example User - Administrator";
    email = "example@example.com";
    gitUser = "example-user";
    isAdmin = true;

    # Placeholder SSH key - REPLACE with your actual public key
    # Generate with: ssh-keygen -t ed25519 -C "your-email@example.com"
    sshKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIExampleKeyForCITestingOnlyDoNotUseInProduction example@example.com"
    ];

    extraGroups = [ "networkmanager" ];
  };

  # ─────────────────────────────────────────────────────────────────────────────
  # exampledev - Example Developer (non-admin)
  # ─────────────────────────────────────────────────────────────────────────────
  exampledev = {
    name = "exampledev";
    uid = 1001;
    description = "Example Developer";
    email = "dev@example.com";
    gitUser = "example-dev";
    isAdmin = false;

    sshKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAnotherExampleKeyForTestingOnlyNotForProduction dev@example.com"
    ];

    extraGroups = [ ];
  };

  # ─────────────────────────────────────────────────────────────────────────────
  # Collection Fields (REQUIRED)
  # ─────────────────────────────────────────────────────────────────────────────
  # These fields aggregate user information for iteration in modules.

  allUserNames = [
    "exampleuser"
    "exampledev"
  ];

  adminUserNames = [ "exampleuser" ];

  # ─────────────────────────────────────────────────────────────────────────────
  # Service Configuration
  # ─────────────────────────────────────────────────────────────────────────────

  codeServerPorts = {
    exampleuser = 8080;
    exampledev = 8081;
  };

  # ─────────────────────────────────────────────────────────────────────────────
  # Container Orchestrator Configuration (009-devcontainer-orchestrator)
  # ─────────────────────────────────────────────────────────────────────────────
  # These settings control dev container behavior on the orchestrator.
  # Consumer should override opVault with their actual 1Password vault name.
  #
  # Required 1Password setup (done by consumer):
  #   1. Create Service Account with read access to the vault
  #   2. Set OP_SERVICE_ACCOUNT_TOKEN on orchestrator (systemd credential, agenix, etc.)
  #   3. Create items: {username}-tailscale-authkey for each user
  #
  # Required Tailscale setup (done by consumer in homelab-iac):
  #   1. Create tags: tag:devcontainer, tag:{username}-container
  #   2. Create auth keys with tags, reusable=true, ephemeral=true
  #   3. Configure ACLs for user isolation

  containers = {
    # 1Password vault containing Tailscale auth keys
    # Item naming convention: {username}-tailscale-authkey
    # Reference format: op://{opVault}/{username}-tailscale-authkey/password
    opVault = "DevBox";

    # Resource limits
    maxPerUser = 5; # Max containers per user
    maxGlobal = 7; # Max containers on orchestrator (based on host resources)
    defaultCpu = 2; # CPU cores per container
    defaultMemory = "4G"; # RAM per container

    # Lifecycle automation
    idleStopDays = 7; # Auto-stop after N days of inactivity
    stoppedDestroyDays = 14; # Auto-destroy after N days in stopped state
  };
}
