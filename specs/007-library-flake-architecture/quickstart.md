# Consumer Quickstart Guide

**Feature**: 007-library-flake-architecture  
**Date**: 2025-01-22  
**Audience**: Users who want to use nix-devbox as a base for their own machine

## Overview

This guide walks you through creating a private repository that uses nix-devbox as a library flake. You'll provide your personal data (SSH keys, email, etc.) and hardware configuration, while nix-devbox provides the NixOS modules and sensible defaults.

**Time to complete**: ~15 minutes

## Prerequisites

- NixOS installed (or ability to install it)
- Nix with flakes enabled
- Git for version control
- Your SSH public key(s)
- Your machine's hardware configuration (or ability to generate it)

## Step 1: Create Your Private Repository

```bash
mkdir my-devbox-config
cd my-devbox-config
git init
```

## Step 2: Create flake.nix

Create `flake.nix` with the following content:

```nix
{
  description = "My personal devbox configuration";

  inputs = {
    # Import nix-devbox from FlakeHub
    nix-devbox.url = "https://flakehub.com/f/coal-bap/nix-devbox/*";
    
    # Follow nix-devbox's nixpkgs for consistency
    nixpkgs.follows = "nix-devbox/nixpkgs";
    home-manager.follows = "nix-devbox/home-manager";
  };

  outputs = { self, nix-devbox, nixpkgs, home-manager, ... }:
  let
    # Import your personal user data
    users = import ./users.nix;
  in {
    nixosConfigurations = {
      # Replace 'mydevbox' with your preferred hostname
      mydevbox = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";  # or "aarch64-linux"
        
        # Pass user data to all NixOS modules
        specialArgs = { inherit users; };
        
        modules = [
          # All nix-devbox NixOS modules
          nix-devbox.nixosModules.default
          
          # Your hardware configuration
          ./hardware/devbox.nix
          
          # Home Manager integration
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = { inherit users; };
              
              # Create HM config for each user
              users = builtins.listToAttrs (map (name: {
                inherit name;
                value = {
                  imports = [ nix-devbox.homeManagerModules.profiles.developer ];
                  
                  # User-specific git config
                  programs.git.userName = users.${name}.gitUser;
                  programs.git.userEmail = users.${name}.email;
                  
                  # Required by Home Manager
                  home.stateVersion = "25.05";
                };
              }) users.allUserNames);
            };
          }
        ];
      };
    };
  };
}
```

## Step 3: Create users.nix

Create `users.nix` with your personal information:

```nix
{
  # ─────────────────────────────────────────────────────────────────────────────
  # Your User Account
  # ─────────────────────────────────────────────────────────────────────────────
  myuser = {
    name = "myuser";                              # Your username
    uid = 1000;                                   # User ID (1000 is typical for first user)
    description = "My Name - Developer";          # Human-readable description
    email = "you@example.com";                    # Your email (used for git)
    gitUser = "your-github-username";             # Your GitHub username
    isAdmin = true;                               # true = sudo access
    sshKeys = [
      # Your SSH public key (from ~/.ssh/id_ed25519.pub or similar)
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... your-key-comment"
    ];
    extraGroups = [ "networkmanager" ];           # Optional extra groups
  };

  # ─────────────────────────────────────────────────────────────────────────────
  # Add more users if needed (optional)
  # ─────────────────────────────────────────────────────────────────────────────
  # anotheruser = { ... };

  # ─────────────────────────────────────────────────────────────────────────────
  # Collection Fields (REQUIRED)
  # ─────────────────────────────────────────────────────────────────────────────
  allUserNames = [ "myuser" ];                    # List all usernames
  adminUserNames = [ "myuser" ];                  # List users with isAdmin = true

  # ─────────────────────────────────────────────────────────────────────────────
  # Service Configuration
  # ─────────────────────────────────────────────────────────────────────────────
  codeServerPorts = {
    myuser = 8080;                                # Port for code-server (VS Code in browser)
    # anotheruser = 8081;
  };
}
```

## Step 4: Create Hardware Configuration

Create the `hardware/` directory:

```bash
mkdir hardware
```

### Option A: Generate from existing NixOS

If you already have NixOS installed:

```bash
nixos-generate-config --show-hardware-config > hardware/devbox.nix
```

### Option B: Minimal example

Create `hardware/devbox.nix` with a minimal configuration (you'll need to customize for your machine):

```nix
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # Boot configuration
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Filesystem mounts (CUSTOMIZE THESE)
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/YOUR-ROOT-UUID";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/YOUR-BOOT-UUID";
    fsType = "vfat";
  };

  # Hardware-specific settings
  hardware.enableRedistributableFirmware = true;
  
  # State version (don't change after initial install)
  system.stateVersion = "25.05";
}
```

## Step 5: Build and Test

Test your configuration locally:

```bash
# Build without deploying
nix build .#nixosConfigurations.mydevbox.config.system.build.toplevel

# If successful, you should see a 'result' symlink
ls -la result
```

## Step 6: Deploy

### First-time installation

Boot into a NixOS installer and:

```bash
# Mount your filesystems
mount /dev/disk/by-uuid/YOUR-ROOT-UUID /mnt
mount /dev/disk/by-uuid/YOUR-BOOT-UUID /mnt/boot

# Clone your config
git clone https://github.com/you/my-devbox-config /mnt/etc/nixos

# Install
nixos-install --flake /mnt/etc/nixos#mydevbox
```

### Subsequent updates

```bash
# From your machine
sudo nixos-rebuild switch --flake .#mydevbox
```

## Step 7: Keep Your Config Private

Add a `.gitignore`:

```
result
result-*
```

Push to a private Git repository:

```bash
git add .
git commit -m "Initial devbox configuration"
git remote add origin git@github.com:you/my-devbox-config.git
git push -u origin main
```

## Updating nix-devbox

When nix-devbox releases updates:

```bash
# Update the flake input
nix flake update nix-devbox

# Rebuild
sudo nixos-rebuild switch --flake .#mydevbox
```

## Customization

### Override defaults

Add overrides in your flake.nix modules list:

```nix
modules = [
  nix-devbox.nixosModules.default
  ./hardware/devbox.nix
  
  # Your overrides
  {
    time.timeZone = "America/New_York";
    networking.hostName = "my-custom-hostname";
    
    # Add extra packages
    environment.systemPackages = with pkgs; [
      htop
      vim
    ];
  }
];
```

### Use selective modules

Instead of `nixosModules.default`, import only what you need:

```nix
modules = [
  nix-devbox.nixosModules.core
  nix-devbox.nixosModules.ssh
  nix-devbox.nixosModules.users
  # ... only the modules you want
];
```

### Different Home Manager profile

Use `minimal` instead of `developer`:

```nix
imports = [ nix-devbox.homeManagerModules.profiles.minimal ];
```

## Troubleshooting

### "User 'X' is missing required fields"

Check your `users.nix` has all required fields. See [data-model.md](./data-model.md) for the complete schema.

### "uid must be 1000-65533"

Your UID is in the system range (0-999). Use 1000 or higher.

### Build fails with FlakeHub error

FlakeHub may be temporarily unavailable. Options:
1. Wait and retry
2. Temporarily use GitHub URL: `nix-devbox.url = "github:coal-bap/nix-devbox";`

### Hardware configuration errors

Run `nixos-generate-config --show-hardware-config` on your target machine to get correct disk UUIDs and hardware settings.

## Directory Structure Summary

After completing this guide, your repository should look like:

```
my-devbox-config/
├── flake.nix       # Main configuration (~50 lines)
├── flake.lock      # Locked dependencies (auto-generated)
├── users.nix       # Your personal data (~30 lines)
├── hardware/
│   └── devbox.nix  # Your hardware config
└── .gitignore
```

## Next Steps

- Read [LIBRARY-ARCHITECTURE.md](../../docs/LIBRARY-ARCHITECTURE.md) to understand how nix-devbox works
- Review [USER-DATA-SCHEMA.md](../../docs/USER-DATA-SCHEMA.md) for complete schema reference
- Check the [example consumer flake](../../examples/consumer-flake/) for a complete working example

## Getting Help

- Open an issue on the nix-devbox repository
- Check existing documentation in the `docs/` folder