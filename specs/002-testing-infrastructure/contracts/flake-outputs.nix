# Contract: Expected Flake Output Structure
#
# This file documents the expected shape of flake outputs after
# implementing the testing infrastructure feature.
#
# NOTE: This is a documentation file, not executable Nix code.

{
  # Existing outputs (from 001-devbox-skeleton)
  nixosConfigurations.devbox = { /* NixOS configuration */ };

  # New outputs for testing infrastructure
  
  # Pre-commit checks - one per supported system
  checks = {
    x86_64-linux.pre-commit-check = {
      # Derivation from git-hooks.nix
      # Key attributes:
      shellHook = "/* script to install git hooks */";
      enabledPackages = [ /* nixfmt statix deadnix */ ];
    };
    aarch64-linux.pre-commit-check = { /* same structure */ };
    x86_64-darwin.pre-commit-check = { /* same structure */ };
    aarch64-darwin.pre-commit-check = { /* same structure */ };
  };

  # Development shells with auto-installed hooks
  devShells = {
    x86_64-linux.default = {
      # mkShell with:
      # - shellHook inherited from pre-commit-check
      # - buildInputs including enabledPackages
    };
    aarch64-linux.default = { /* same structure */ };
    x86_64-darwin.default = { /* same structure */ };
    aarch64-darwin.default = { /* same structure */ };
  };

  # Optional: formatter output for `nix fmt`
  formatter = {
    x86_64-linux = "/* nixfmt-rfc-style package */";
    aarch64-linux = "/* nixfmt-rfc-style package */";
    x86_64-darwin = "/* nixfmt-rfc-style package */";
    aarch64-darwin = "/* nixfmt-rfc-style package */";
  };
}
