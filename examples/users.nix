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

    # Resource quota for container-host (optional)
    # Limits CPU, memory, and storage for this user's containers
    # Admins typically don't have quotas; non-admin users should
    resourceQuota = {
      cpuCores = 2; # Max 2 CPU cores (systemd CPUQuota=200%)
      memoryGB = 4; # Max 4GB memory (systemd MemoryMax=4G)
      storageGB = 50; # Max 50GB container storage (filesystem quota)
    };
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
}
