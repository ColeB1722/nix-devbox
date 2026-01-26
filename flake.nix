# nix-devbox flake
#
# A library-style flake that exports reusable NixOS and Home Manager modules
# for secure, headless development machines. Access via SSH over Tailscale only.
#
# Architecture:
#   - Public flake (this repo): Exports modules, no personal data
#   - Consumer flake (private): Imports this, provides users + hardware
#
# Usage (consumer):
#   inputs.nix-devbox.url = "https://flakehub.com/f/coal-bap/nix-devbox/*";
#   modules = [ nix-devbox.nixosModules.default ./hardware.nix ];
#   specialArgs = { users = import ./users.nix; };
#
# Usage (this repo CI):
#   nix flake check                          # Validate flake structure
#   nix build .#nixosConfigurations.devbox.config.system.build.toplevel
#
# Constitution: All configuration is declarative, headless-first, secure by
# default, modular, and self-documenting.

{
  description = "Library flake: reusable NixOS modules for secure, headless development machines";

  inputs = {
    # NixOS 25.05 stable channel
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

    # Nixpkgs unstable for packages that need newer versions (e.g., security updates)
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

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

    # nix-darwin for macOS system configuration
    # Enables declarative macOS management alongside NixOS
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # System types for multi-platform support
    systems.url = "github:nix-systems/default";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-unstable,
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

      # Example user data for CI builds (no personal data)
      # Consumers provide their own users.nix with real data
      exampleUsers = import ./examples/users.nix;

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

            # Note: check-ssh-keys hook removed - SSH public keys are safe to commit
            # (they are designed to be shared, unlike private keys)
          };
        };

      # Common nixpkgs config for all configurations
      mkNixpkgsConfig = _system: {
        # Allow specific unfree packages required by feature 005-devtools-config
        # Constitution: Explicitly allowlist unfree packages rather than blanket allowUnfree
        nixpkgs.config.allowUnfreePredicate =
          pkg:
          builtins.elem (nixpkgs.lib.getName pkg) [
            "1password-cli" # Secrets management (FR-023)
            "claude-code" # AI coding assistant (FR-011)
            "terraform" # Infrastructure as code (FR-022)
          ];

        # Overlay: Use unstable Tailscale for security updates
        # nixos-25.05 stable has older Tailscale; unstable has security patches
        nixpkgs.overlays = [
          (_final: prev: {
            inherit (nixpkgs-unstable.legacyPackages.${prev.system}) tailscale;
          })
        ];
      };
    in
    {
      # ─────────────────────────────────────────────────────────────────────────
      # Module Exports (for consumers)
      # ─────────────────────────────────────────────────────────────────────────
      # Consumers import these modules and provide their own user data via specialArgs

      nixosModules = {
        # Individual NixOS modules
        core = import ./nixos/core.nix;
        ssh = import ./nixos/ssh.nix;
        firewall = import ./nixos/firewall.nix;
        tailscale = import ./nixos/tailscale.nix;
        docker = import ./nixos/docker.nix;
        fish = import ./nixos/fish.nix;
        users = import ./nixos/users.nix;
        code-server = import ./nixos/code-server.nix;
        podman = import ./nixos/podman.nix;
        hyprland = import ./nixos/hyprland.nix;
        syncthing = import ./nixos/syncthing.nix;
        ttyd = import ./nixos/ttyd.nix;

        # All NixOS modules combined (most consumers want this)
        default = {
          imports = [
            ./nixos/core.nix
            ./nixos/ssh.nix
            ./nixos/firewall.nix
            ./nixos/tailscale.nix
            ./nixos/docker.nix
            ./nixos/fish.nix
            ./nixos/users.nix
            ./nixos/code-server.nix
          ];
        };
      };

      # ─────────────────────────────────────────────────────────────────────────
      # Darwin Module Exports (for macOS consumers)
      # ─────────────────────────────────────────────────────────────────────────
      darwinModules = {
        # Individual darwin modules
        core = import ./darwin/core.nix;
        aerospace = import ./darwin/aerospace.nix;

        # All darwin modules combined
        default = {
          imports = [
            ./darwin/core.nix
            ./darwin/aerospace.nix
          ];
        };
      };

      homeManagerModules = {
        # Individual Home Manager modules
        cli = import ./home/modules/cli.nix;
        fish = import ./home/modules/fish.nix;
        git = import ./home/modules/git.nix;
        dev = import ./home/modules/dev.nix;

        # Home Manager profiles (composable bundles)
        profiles = {
          minimal = import ./home/profiles/minimal.nix;
          developer = import ./home/profiles/developer.nix;
        };
      };

      # Host definitions (importable templates)
      # Consumers import these and provide hardware + users
      hosts = {
        devbox = import ./hosts/devbox;
        devbox-wsl = import ./hosts/devbox-wsl;
        devbox-desktop = import ./hosts/devbox-desktop;
        macbook = import ./hosts/macbook;
      };

      # ─────────────────────────────────────────────────────────────────────────
      # Example Configurations (for CI and testing)
      # ─────────────────────────────────────────────────────────────────────────
      # These use example/placeholder data - no personal information

      nixosConfigurations = {
        # Primary devbox configuration (bare metal / VM)
        # Uses example users and hardware for CI builds
        devbox = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";

          # Pass example users + flake inputs to all modules
          specialArgs = {
            inherit inputs;
            users = exampleUsers;
          };

          modules = [
            # Host definition (imports all NixOS modules)
            ./hosts/devbox

            # Example hardware configuration for CI
            ./examples/hardware-example.nix

            # Home Manager as NixOS module for atomic system+user updates
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                extraSpecialArgs = {
                  inherit inputs;
                  users = exampleUsers;
                };
                # Import developer profile for all users
                users = builtins.listToAttrs (
                  map (name: {
                    inherit name;
                    value = {
                      imports = [ ./home/profiles/developer.nix ];
                    };
                  }) exampleUsers.allUserNames
                );
              };
            }

            # Nixpkgs configuration
            (mkNixpkgsConfig "x86_64-linux")
          ];
        };

        # WSL configuration (Windows Subsystem for Linux)
        # Uses example users for CI builds
        devbox-wsl = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";

          # Pass example users + flake inputs to all modules
          specialArgs = {
            inherit inputs;
            users = exampleUsers;
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
                useGlobalPkgs = true;
                useUserPackages = true;
                extraSpecialArgs = {
                  inherit inputs;
                  users = exampleUsers;
                };
                # Import developer profile for all users
                users = builtins.listToAttrs (
                  map (name: {
                    inherit name;
                    value = {
                      imports = [ ./home/profiles/developer.nix ];
                    };
                  }) exampleUsers.allUserNames
                );
              };
            }

            # Nixpkgs configuration
            (mkNixpkgsConfig "x86_64-linux")
          ];
        };

        # Headful NixOS Desktop (bare metal workstation with Hyprland)
        # Uses example users and hardware for CI builds
        devbox-desktop = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";

          # Pass example users + flake inputs to all modules
          specialArgs = {
            inherit inputs;
            users = exampleUsers;
          };

          modules = [
            # Host definition (imports NixOS modules + Hyprland)
            ./hosts/devbox-desktop

            # Example hardware configuration for CI
            ./examples/hardware-example.nix

            # Home Manager as NixOS module for atomic system+user updates
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                extraSpecialArgs = {
                  inherit inputs;
                  users = exampleUsers;
                };
                # Import developer profile for all users
                users = builtins.listToAttrs (
                  map (name: {
                    inherit name;
                    value = {
                      imports = [ ./home/profiles/developer.nix ];
                    };
                  }) exampleUsers.allUserNames
                );
              };
            }

            # Nixpkgs configuration
            (mkNixpkgsConfig "x86_64-linux")
          ];
        };
      };

      # ─────────────────────────────────────────────────────────────────────────
      # Darwin Configurations (for macOS)
      # ─────────────────────────────────────────────────────────────────────────
      # Example macOS configuration for CI and testing
      # Uses example users - consumers provide their own user data

      darwinConfigurations = {
        # Example macOS workstation configuration
        # Consumers should create their own with actual user data
        macbook = inputs.nix-darwin.lib.darwinSystem {
          system = "aarch64-darwin";

          specialArgs = {
            inherit inputs;
            users = exampleUsers;
          };

          modules = [
            # Darwin host configuration
            ./hosts/macbook

            # Home Manager as darwin module
            home-manager.darwinModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                extraSpecialArgs = {
                  inherit inputs;
                  users = exampleUsers;
                };
                users = builtins.listToAttrs (
                  map (name: {
                    inherit name;
                    value = {
                      imports = [ ./home/profiles/workstation.nix ];
                    };
                  }) exampleUsers.allUserNames
                );
              };
            }
          ];
        };
      };

      # ─────────────────────────────────────────────────────────────────────────
      # Library Exports (for consumers)
      # ─────────────────────────────────────────────────────────────────────────

      # Schema validation functions
      lib = {
        schema = import ./lib/schema.nix { inherit (nixpkgs) lib; };
        mkHost = import ./lib/mkHost.nix { inherit (nixpkgs) lib; };
        containers = import ./lib/containers.nix { inherit (nixpkgs) lib; };
      };

      # ─────────────────────────────────────────────────────────────────────────
      # Packages (Container Images)
      # ─────────────────────────────────────────────────────────────────────────
      # Container images for the dev container orchestrator (Linux only)
      # Build with: nix build .#packages.x86_64-linux.devcontainer

      packages =
        let
          # Container images are Linux-only (OCI containers)
          linuxSystems = [
            "x86_64-linux"
            "aarch64-linux"
          ];
        in
        nixpkgs.lib.genAttrs linuxSystems (
          system:
          let
            pkgs = import nixpkgs {
              inherit system;
              config.allowUnfree = true;
            };
          in
          {
            # Dev container image (OCI format)
            # Load into Podman with: podman load < result
            devcontainer = import ./containers/devcontainer { inherit pkgs; };
          }
        );

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
