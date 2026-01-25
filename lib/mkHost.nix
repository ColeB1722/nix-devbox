# Host Composition Helper
#
# This module provides helper functions for consumers to compose
# host definitions with their own user data and hardware configurations.
#
# Usage in consumer flake.nix:
#   let
#     mkHost = import "${nix-devbox}/lib/mkHost.nix" { inherit lib; };
#   in
#     nixosConfigurations.mybox = mkHost {
#       system = "x86_64-linux";
#       users = import ./users.nix;
#       hardware = ./hardware/mybox.nix;
#       host = nix-devbox.hosts.devbox;
#       extraModules = [ ];
#     };
#
# Constitution alignment:
#   - Principle IV: Modular and Reusable (simplifies consumer configuration)
#   - Principle V: Documentation as Code (clear usage patterns)

_:

{
  # ─────────────────────────────────────────────────────────────────────────────
  # Host Composition
  # ─────────────────────────────────────────────────────────────────────────────

  # Create a NixOS configuration by composing:
  #   - A host definition from nix-devbox
  #   - Consumer-provided user data
  #   - Consumer-provided hardware configuration
  #   - Optional extra modules
  #
  # Arguments:
  #   nixpkgs    - The nixpkgs input from consumer's flake
  #   system     - Target system (e.g., "x86_64-linux")
  #   users      - User data attrset (from consumer's users.nix)
  #   hardware   - Path to hardware configuration module
  #   host       - Host definition module from nix-devbox.hosts
  #   homeManager - Home Manager nixosModules.home-manager
  #   homeManagerModules - nix-devbox.homeManagerModules for profiles
  #   extraModules - Additional NixOS modules (optional)
  #   extraSpecialArgs - Additional specialArgs (optional)
  #
  mkHost =
    {
      nixpkgs,
      system,
      users,
      hardware,
      host,
      homeManager,
      homeManagerModules ? { },
      extraModules ? [ ],
      extraSpecialArgs ? { },
    }:
    nixpkgs.lib.nixosSystem {
      inherit system;

      # Pass user data and extra args to all NixOS modules
      specialArgs = {
        inherit users;
      }
      // extraSpecialArgs;

      modules = [
        # Host definition (includes all nix-devbox NixOS modules)
        host

        # Consumer's hardware configuration
        hardware

        # Home Manager integration
        homeManager
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            extraSpecialArgs = {
              inherit users;
            }
            // extraSpecialArgs;

            # Create Home Manager config for each user
            users = builtins.listToAttrs (
              map (name: {
                inherit name;
                value =
                  { ... }:
                  {
                    imports =
                      # Use developer profile by default if available
                      if homeManagerModules ? profiles && homeManagerModules.profiles ? developer then
                        [ homeManagerModules.profiles.developer ]
                      else
                        [ ];

                    # User-specific git configuration
                    programs.git = {
                      userName = users.${name}.gitUser;
                      userEmail = users.${name}.email;
                    };

                    # Note: home.stateVersion is set by imported profiles (developer.nix, minimal.nix)
                  };
              }) users.allUserNames
            );
          };
        }

        # Consumer's extra modules
      ]
      ++ extraModules;
    };

  # ─────────────────────────────────────────────────────────────────────────────
  # Simplified Host Builder
  # ─────────────────────────────────────────────────────────────────────────────

  # A simpler version for common use cases where you just want to
  # provide users and hardware to an existing host definition.
  #
  # This is a curried function that takes nix-devbox inputs first,
  # then consumer configuration.
  #
  # Usage:
  #   let
  #     mkDevbox = mkHostWith {
  #       inherit nixpkgs home-manager;
  #       hostModules = nix-devbox.nixosModules;
  #       hmModules = nix-devbox.homeManagerModules;
  #     };
  #   in
  #     nixosConfigurations.mybox = mkDevbox {
  #       system = "x86_64-linux";
  #       users = import ./users.nix;
  #       hardware = ./hardware/mybox.nix;
  #     };
  #
  mkHostWith =
    {
      nixpkgs,
      home-manager,
      hostModules,
      hmModules,
    }:
    {
      system,
      users,
      hardware,
      extraModules ? [ ],
      extraSpecialArgs ? { },
    }:
    nixpkgs.lib.nixosSystem {
      inherit system;

      specialArgs = {
        inherit users;
      }
      // extraSpecialArgs;

      modules = [
        # Use the default module which includes all NixOS modules
        hostModules.default

        # Consumer's hardware
        hardware

        # Home Manager
        home-manager.nixosModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            extraSpecialArgs = {
              inherit users;
            }
            // extraSpecialArgs;

            users = builtins.listToAttrs (
              map (name: {
                inherit name;
                value =
                  { ... }:
                  {
                    imports =
                      if hmModules ? profiles && hmModules.profiles ? developer then
                        [ hmModules.profiles.developer ]
                      else
                        [ ];

                    programs.git = {
                      userName = users.${name}.gitUser;
                      userEmail = users.${name}.email;
                    };

                    # Note: home.stateVersion is set by imported profiles (developer.nix, minimal.nix)
                  };
              }) users.allUserNames
            );
          };
        }
      ]
      ++ extraModules;
    };
}
