# Example Hardware Configuration for CI and Testing
#
# This file provides a minimal hardware configuration that allows the public
# flake to build in CI without requiring actual hardware-specific details.
#
# For your own configuration, generate your hardware config with:
#   nixos-generate-config --show-hardware-config > hardware/devbox.nix
#
# Or copy this template and customize the filesystem UUIDs.

{
  config,
  lib,
  modulesPath,
  ...
}:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  # ─────────────────────────────────────────────────────────────────────────────
  # Boot Configuration
  # ─────────────────────────────────────────────────────────────────────────────
  # Uses GRUB bootloader to match core.nix defaults
  # Consumer hardware configs can override with systemd-boot if preferred

  boot = {
    loader = {
      grub = {
        enable = true;
        device = "/dev/sda"; # Example device - consumer should override
        efiSupport = true;
      };
      efi.canTouchEfiVariables = true;
    };

    # Kernel modules for common hardware
    initrd.availableKernelModules = [
      "ahci"
      "xhci_pci"
      "virtio_pci"
      "virtio_scsi"
      "sd_mod"
      "sr_mod"
    ];

    kernelModules = [ "kvm-intel" ];
  };

  # ─────────────────────────────────────────────────────────────────────────────
  # Filesystem Configuration
  # ─────────────────────────────────────────────────────────────────────────────
  #
  # IMPORTANT: These are placeholder UUIDs for CI testing only.
  # In a real configuration, replace with your actual disk UUIDs.
  # Get your UUIDs with: blkid
  #
  # For CI builds, we use fileSystems with `neededForBoot = false` to allow
  # the configuration to evaluate without requiring actual disks.

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/00000000-0000-0000-0000-000000000000";
    fsType = "ext4";
    # Allow build to succeed even without real disk
    options = [ "defaults" ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/0000-0000";
    fsType = "vfat";
    options = [
      "fmask=0022"
      "dmask=0022"
    ];
  };

  # No swap for CI builds
  swapDevices = [ ];

  # ─────────────────────────────────────────────────────────────────────────────
  # Hardware Settings
  # ─────────────────────────────────────────────────────────────────────────────

  # Enable firmware for common hardware
  hardware.enableRedistributableFirmware = lib.mkDefault true;

  # CPU microcode updates (Intel example - adjust for AMD)
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # ─────────────────────────────────────────────────────────────────────────────
  # Networking
  # ─────────────────────────────────────────────────────────────────────────────

  # Use DHCP for network configuration
  networking.useDHCP = lib.mkDefault true;

  # ─────────────────────────────────────────────────────────────────────────────
  # State Version
  # ─────────────────────────────────────────────────────────────────────────────
  # Do NOT change this after initial deployment

  system.stateVersion = "25.05";
}
