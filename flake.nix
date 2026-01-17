# nix-devbox flake
#
# A minimal, secure, modular NixOS configuration for a self-hosted remote
# development machine. Access via SSH over Tailscale only.
#
# Usage:
#   nix flake check                          # Validate flake structure
#   nixos-rebuild build --flake .#devbox     # Build without deploying
#   sudo nixos-rebuild switch --flake .#devbox  # Deploy to current machine
#
# Constitution: All configuration is declarative, headless-first, secure by
# default, modular, and self-documenting.

{
  description = "NixOS configuration for a secure, headless development machine";

  inputs = {
    # NixOS 24.05 stable channel
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";

    # Home Manager for user environment management
    # Follows nixpkgs to ensure package consistency
    home-manager = {
      url = "github:nix-community/home-manager/release-24.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs: {
    # NixOS system configurations
    # Each host gets its own configuration under nixosConfigurations.<hostname>
    nixosConfigurations = {
      # Primary devbox configuration
      devbox = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        # Pass flake inputs to all modules via specialArgs
        specialArgs = { inherit inputs; };

        modules = [
          # Machine-specific configuration
          ./hosts/devbox

          # Home Manager as NixOS module for atomic system+user updates
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;      # Use system nixpkgs
            home-manager.useUserPackages = true;   # Install to /etc/profiles
            home-manager.extraSpecialArgs = { inherit inputs; };
          }
        ];
      };
    };
  };
}
