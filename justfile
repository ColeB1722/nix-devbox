# nix-devbox justfile
#
# Common development and deployment tasks for the NixOS devbox configuration.
# Run `just` to see available targets, or `just <target>` to execute.
#
# Prerequisites: Nix with flakes enabled

# Default recipe: show available targets
default:
    @just --list

# ─────────────────────────────────────────────────────────────────────────────
# Development
# ─────────────────────────────────────────────────────────────────────────────

# Enter development shell with pre-commit hooks
develop:
    nix develop

# Run all flake checks (pre-commit hooks + NixOS eval)
check:
    nix flake check

# Build NixOS configuration without deploying
build:
    nix build .#nixosConfigurations.devbox.config.system.build.toplevel

# Show flake outputs
show:
    nix flake show

# ─────────────────────────────────────────────────────────────────────────────
# Code Quality
# ─────────────────────────────────────────────────────────────────────────────

# Format all Nix files
fmt:
    nix fmt

# Run all linters (statix + deadnix)
lint:
    nix develop -c statix check .
    nix develop -c deadnix .

# Auto-fix linting issues
lint-fix:
    nix develop -c statix fix .
    nix develop -c deadnix -e .

# Run pre-commit hooks on all files
hooks:
    nix develop -c pre-commit run --all-files

# ─────────────────────────────────────────────────────────────────────────────
# Deployment (run on target machine)
# ─────────────────────────────────────────────────────────────────────────────

# Deploy configuration to current machine
deploy:
    sudo nixos-rebuild switch --flake .#devbox

# Deploy on next boot only (safer for remote machines)
boot:
    sudo nixos-rebuild boot --flake .#devbox

# Test configuration without adding to bootloader (activates temporarily until reboot)
test:
    sudo nixos-rebuild test --flake .#devbox

# Rollback to previous generation
rollback:
    sudo nixos-rebuild switch --rollback

# List system generations
generations:
    sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

# ─────────────────────────────────────────────────────────────────────────────
# Maintenance
# ─────────────────────────────────────────────────────────────────────────────

# Update all flake inputs
update:
    nix flake update

# Update a specific input (e.g., just update-input nixpkgs)
update-input input:
    nix flake update {{input}}

# Garbage collect old generations (removes generations older than 30 days)
gc:
    sudo nix-collect-garbage --delete-older-than 30d
    nix-collect-garbage --delete-older-than 30d

# Remove all old generations and garbage collect
gc-all:
    sudo nix-collect-garbage -d
    nix-collect-garbage -d

# Show disk usage of Nix store
disk:
    nix path-info -Sh .#nixosConfigurations.devbox.config.system.build.toplevel

# ─────────────────────────────────────────────────────────────────────────────
# CI / Validation
# ─────────────────────────────────────────────────────────────────────────────

# Run full CI validation locally
ci: check build
    @echo "CI validation passed!"

# Validate flake without building
validate:
    nix flake check --no-build
