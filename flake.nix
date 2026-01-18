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

    # Pre-commit hooks for code quality
    # Provides sandboxed hook execution via `nix flake check`
    # Note: Uses its own nixpkgs to avoid version incompatibility with 24.05
    git-hooks.url = "github:cachix/git-hooks.nix";

    # System types for multi-platform support
    systems.url = "github:nix-systems/default";
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      git-hooks,
      systems,
      ...
    }@inputs:
    let
      # Helper function to generate outputs for all supported systems
      # Supports: x86_64-linux, aarch64-linux, x86_64-darwin, aarch64-darwin
      forEachSystem = nixpkgs.lib.genAttrs (import systems);

      # Pre-commit hook configuration for code quality checks
      # Runs nixfmt-rfc-style, statix, and deadnix on all .nix files
      mkPreCommitCheck =
        system:
        git-hooks.lib.${system}.run {
          src = ./.;
          hooks = {
            # Format Nix files using RFC-style formatter (nixpkgs standard)
            nixfmt-rfc-style.enable = true;
            # Detect antipatterns and inefficient Nix code
            statix.enable = true;
            # Find unused variables and function arguments
            deadnix.enable = true;
          };
        };
    in
    {
      # NixOS system configurations
      # Each host gets its own configuration under nixosConfigurations.<hostname>
      nixosConfigurations = {
        # Primary devbox configuration
        devbox = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";

          # Pass flake inputs to all modules via specialArgs
          specialArgs = {
            inherit inputs;
          };

          modules = [
            # Machine-specific configuration
            ./hosts/devbox

            # Home Manager as NixOS module for atomic system+user updates
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true; # Use system nixpkgs
              home-manager.useUserPackages = true; # Install to /etc/profiles
              home-manager.extraSpecialArgs = {
                inherit inputs;
              };
            }
          ];
        };
      };

      # Pre-commit checks for each supported system
      # Run via `nix flake check` for sandboxed validation
      checks = forEachSystem (system: {
        pre-commit-check = mkPreCommitCheck system;
      });

      # Development shell with pre-commit hooks auto-installed
      # Enter via `nix develop` to get hooks and tools
      devShells = forEachSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            # Auto-install git hooks when entering shell
            inherit (self.checks.${system}.pre-commit-check) shellHook;
            # Provide hook tools (nixfmt, statix, deadnix) and dev utilities
            buildInputs = self.checks.${system}.pre-commit-check.enabledPackages ++ [
              pkgs.just # Task runner for common commands
            ];
          };
        }
      );

      # Formatter for `nix fmt` command
      # Uses nixfmt-rfc-style (emerging nixpkgs standard per RFC 166)
      formatter = forEachSystem (system: nixpkgs.legacyPackages.${system}.nixfmt-rfc-style);
    };
}
