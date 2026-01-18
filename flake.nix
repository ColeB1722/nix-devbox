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
    # NixOS 25.05 stable channel
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

    # Home Manager for user environment management
    # Follows nixpkgs to ensure package consistency
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # NixOS-WSL for running NixOS on Windows Subsystem for Linux
    # Uses release branch for automatic patch updates via `nix flake update`
    # Version scheme: 25.05 = NixOS 25.05 compatible
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/release-25.05";
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
      nixos-wsl,
      git-hooks,
      systems,
      ...
    }@inputs:
    let
      # Helper function to generate outputs for all supported systems
      # Supports: x86_64-linux, aarch64-linux, x86_64-darwin, aarch64-darwin
      forEachSystem = nixpkgs.lib.genAttrs (import systems);

      # Pre-commit hook configuration for code quality and security checks
      # Runs formatting, linting, and security scanning on all commits
      mkPreCommitCheck =
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        git-hooks.lib.${system}.run {
          src = ./.;
          hooks = {
            # ─────────────────────────────────────────────────────────────
            # Code Quality Hooks
            # ─────────────────────────────────────────────────────────────

            # Format Nix files using RFC-style formatter (nixpkgs standard)
            nixfmt-rfc-style.enable = true;
            # Detect antipatterns and inefficient Nix code
            statix.enable = true;
            # Find unused variables and function arguments
            # --no-underscore: ignore bindings starting with _ (intentionally unused)
            deadnix = {
              enable = true;
              settings.noUnderscore = true;
            };

            # ─────────────────────────────────────────────────────────────
            # Security Hooks
            # ─────────────────────────────────────────────────────────────

            # Scan for secrets, API keys, and credentials
            gitleaks = {
              enable = true;
              name = "gitleaks";
              description = "Detect hardcoded secrets";
              entry = "${pkgs.gitleaks}/bin/gitleaks protect --staged --verbose --redact";
              pass_filenames = false;
            };

            # Detect private keys (SSH, PGP, etc.)
            # Uses gitleaks pattern matching instead of grep to avoid false positives
            detect-private-key = {
              enable = true;
              name = "detect-private-key";
              description = "Detect private keys";
              entry = ''
                ${pkgs.bash}/bin/bash -c '
                  # Check for actual private key file markers (BEGIN ... PRIVATE KEY)
                  # Exclude flake.nix to avoid matching this hook definition
                  for file in "$@"; do
                    if [[ "$file" != "flake.nix" ]] && [[ -f "$file" ]]; then
                      if grep -l "BEGIN.*PRIVATE" "$file" 2>/dev/null | grep -v "detect-private"; then
                        echo "ERROR: Private key detected in $file!"
                        exit 1
                      fi
                    fi
                  done
                '
              '';
              types = [ "text" ];
            };

            # Verify no real SSH keys are committed (only CI test key allowed)
            check-ssh-keys = {
              enable = true;
              name = "check-ssh-keys";
              description = "Verify SSH keys are safe for public repo";
              entry = ''
                ${pkgs.bash}/bin/bash -c '
                  # Only check modules/user/default.nix where SSH keys are configured
                  for file in "$@"; do
                    if [[ "$file" == "modules/user/default.nix" ]]; then
                      # Look for SSH public keys that are NOT the known CI test key or placeholders
                      if grep -E "ssh-(ed25519|rsa|ecdsa) [A-Za-z0-9+/]+" "$file" 2>/dev/null | \
                         grep -v "ci-test-key@nix-devbox" | \
                         grep -v "Placeholder" | \
                         grep -v "# Example:" | \
                         grep -v "example.com" | \
                         grep -q .; then
                        echo "ERROR: Potentially real SSH key found in $file"
                        echo "Only the CI test key (ci-test-key@nix-devbox) or placeholders are allowed."
                        echo "If deploying, use secret management (agenix/sops-nix) instead."
                        exit 1
                      fi
                    fi
                  done
                '
              '';
              types = [ "file" ];
            };
          };
        };
    in
    {
      # NixOS system configurations
      # Each host gets its own configuration under nixosConfigurations.<hostname>
      nixosConfigurations = {
        # Primary devbox configuration (bare metal / VM)
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
              home-manager = {
                useGlobalPkgs = true; # Use system nixpkgs
                useUserPackages = true; # Install to /etc/profiles
                extraSpecialArgs = {
                  inherit inputs;
                };
              };
            }
          ];
        };

        # WSL configuration (Windows Subsystem for Linux)
        # Use with: sudo nixos-rebuild switch --flake .#devbox-wsl
        devbox-wsl = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";

          # Pass flake inputs to all modules via specialArgs
          specialArgs = {
            inherit inputs;
          };

          modules = [
            # NixOS-WSL base module (MUST be first)
            nixos-wsl.nixosModules.default

            # WSL-specific host configuration
            ./hosts/devbox-wsl

            # Home Manager as NixOS module for atomic system+user updates
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true; # Use system nixpkgs
                useUserPackages = true; # Install to /etc/profiles
                extraSpecialArgs = {
                  inherit inputs;
                };
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
