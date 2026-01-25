# Research: Library-Style Flake Architecture

**Feature**: 007-library-flake-architecture  
**Date**: 2025-01-22  
**Status**: Complete

## Research Tasks

1. Nix module export patterns in established library flakes
2. specialArgs propagation through nixosSystem → modules → Home Manager
3. Schema validation using Nix assertions
4. FlakeHub caching behavior for library flakes

---

## R1: Nix Module Export Patterns

### Question

How do established library flakes structure their module exports for external consumption?

### Findings

Analyzed three major library flakes:

#### nixos-hardware

```nix
# github:NixOS/nixos-hardware
{
  nixosModules = {
    common-cpu-intel = ./common/cpu/intel;
    common-gpu-nvidia = ./common/gpu/nvidia;
    lenovo-thinkpad-t480 = ./lenovo/thinkpad/t480;
    # ... hundreds more
  };
}
```

**Pattern**: Flat namespace, descriptive names, each module is a path to a directory with `default.nix`.

#### sops-nix

```nix
# github:Mic92/sops-nix
{
  nixosModules = {
    sops = ./modules/sops;
    default = self.nixosModules.sops;
  };
  homeManagerModules = {
    sops = ./modules/home-manager/sops.nix;
    default = self.homeManagerModules.sops;
  };
}
```

**Pattern**: Provides both `nixosModules` and `homeManagerModules`. Uses `default` alias for primary module.

#### home-manager

```nix
# github:nix-community/home-manager
{
  nixosModules = {
    home-manager = ./nixos;
    default = self.nixosModules.home-manager;
  };
}
```

**Pattern**: Single NixOS module for integration; `default` alias.

### Decision

Export modules as attribute sets under `nixosModules` and `homeManagerModules`:

```nix
{
  nixosModules = {
    core = import ./nixos/core.nix;
    ssh = import ./nixos/ssh.nix;
    firewall = import ./nixos/firewall.nix;
    tailscale = import ./nixos/tailscale.nix;
    docker = import ./nixos/docker.nix;
    fish = import ./nixos/fish.nix;
    users = import ./nixos/users.nix;
    code-server = import ./nixos/code-server.nix;
    
    # Convenience: import all modules at once
    default = { imports = [ /* all modules */ ]; };
  };
  
  homeManagerModules = {
    cli = import ./home/modules/cli.nix;
    fish = import ./home/modules/fish.nix;
    git = import ./home/modules/git.nix;
    dev = import ./home/modules/dev.nix;
    
    profiles = {
      minimal = import ./home/profiles/minimal.nix;
      developer = import ./home/profiles/developer.nix;
    };
  };
  
  # Host definitions as composable templates
  hosts = {
    devbox = import ./hosts/devbox;
    devbox-wsl = import ./hosts/devbox-wsl;
  };
}
```

### Rationale

- Follows established conventions (sops-nix, home-manager)
- Individual modules allow selective composition
- `default` module provides easy "all-in-one" option
- Nested `profiles` attribute keeps Home Manager organization clean

### Alternatives Considered

1. **Single monolithic module**: Rejected - reduces flexibility, harder to maintain
2. **Function-based modules**: Rejected - adds complexity without benefit for this use case

---

## R2: specialArgs Propagation

### Question

How to pass consumer-provided user data through the module hierarchy: `nixosSystem` → NixOS modules → Home Manager?

### Findings

#### NixOS specialArgs

`specialArgs` is passed to all NixOS modules as function arguments:

```nix
# Consumer flake
nixosConfigurations.devbox = nixpkgs.lib.nixosSystem {
  specialArgs = { 
    users = import ./users.nix;
    customVar = "value";
  };
  modules = [ ... ];
};

# NixOS module receives specialArgs as function args
{ config, lib, pkgs, users, customVar, ... }:
{
  # Can use `users` and `customVar` here
}
```

#### Home Manager extraSpecialArgs

Home Manager has its own `extraSpecialArgs` that propagates to HM modules:

```nix
home-manager.nixosModules.home-manager
{
  home-manager = {
    useGlobalPkgs = true;
    extraSpecialArgs = { 
      inherit users;  # Forward from NixOS specialArgs
      userConfig = users.coal;  # Or transform it
    };
  };
}
```

#### Per-User Configuration

For multi-user setups, each user's HM config can receive user-specific data:

```nix
home-manager.users = builtins.listToAttrs (map (name: {
  inherit name;
  value = { config, ... }: {
    imports = [ ./home/profiles/developer.nix ];
    # User-specific settings passed via extraSpecialArgs or directly
    programs.git.userName = users.${name}.gitUser;
    programs.git.userEmail = users.${name}.email;
  };
}) users.allUserNames);
```

### Decision

1. Consumer passes `users` attrset via `specialArgs`
2. NixOS modules access `users` directly as function argument
3. Home Manager receives `users` via `extraSpecialArgs`
4. Per-user HM configs extract their specific user data from `users.${name}`

### Rationale

- Standard Nix pattern, well-documented
- Clean separation: consumer provides data, modules consume it
- No global state or impure references

### Alternatives Considered

1. **Import path override**: Rejected - requires file path manipulation, fragile
2. **Module options**: Considered - more complex but could provide better validation; deferred to future enhancement

---

## R3: Schema Validation with Assertions

### Question

How to produce clear, actionable error messages when consumer provides invalid user data?

### Findings

#### NixOS Assertions

```nix
{
  assertions = [
    {
      assertion = config.someCondition;
      message = "Descriptive error message";
    }
  ];
}
```

Assertions are collected and evaluated at build time. All failed assertions are reported together.

#### lib.assertMsg for Inline Validation

```nix
let
  validateUser = name: user:
    lib.assertMsg (user ? uid) 
      "User '${name}' is missing required field 'uid'" &&
    lib.assertMsg (user.uid >= 1000) 
      "User '${name}' uid must be >= 1000 (got ${toString user.uid}), system UIDs (0-999) are reserved" &&
    lib.assertMsg (user ? sshKeys && builtins.length user.sshKeys > 0)
      "User '${name}' must have at least one SSH key for remote access";
in
  assert validateUser "coal" users.coal;
  { /* module config */ }
```

#### Combining Both Approaches

Use `assertions` for module-level checks (conditions that depend on `config`), and `lib.assertMsg` chains for data validation that can run at evaluation time.

### Decision

Create `lib/schema.nix` with validation functions:

```nix
{ lib }:
rec {
  # Validate a single user record
  validateUser = name: user: let
    requiredFields = [ "name" "uid" "description" "email" "gitUser" "isAdmin" "sshKeys" ];
    missingFields = builtins.filter (f: !(user ? ${f})) requiredFields;
  in
    lib.assertMsg (missingFields == [])
      "User '${name}' is missing required fields: ${builtins.concatStringsSep ", " missingFields}" &&
    lib.assertMsg (user.uid >= 1000 && user.uid <= 65533)
      "User '${name}' uid must be 1000-65533 (got ${toString user.uid})" &&
    lib.assertMsg (user.uid != 0)
      "User '${name}' uid cannot be 0 (root)" &&
    lib.assertMsg (builtins.length user.sshKeys > 0)
      "User '${name}' must have at least one SSH public key" &&
    lib.assertMsg (builtins.all (k: lib.hasPrefix "ssh-" k) user.sshKeys)
      "User '${name}' has invalid SSH key format (must start with 'ssh-')";

  # Validate entire users attrset
  validateUsers = users: let
    userNames = builtins.filter (n: !(builtins.elem n ["allUserNames" "adminUserNames" "codeServerPorts"])) 
                                (builtins.attrNames users);
  in
    lib.assertMsg (users ? allUserNames)
      "users.nix must define 'allUserNames' list" &&
    lib.assertMsg (users ? adminUserNames)
      "users.nix must define 'adminUserNames' list" &&
    builtins.all (name: validateUser name users.${name}) userNames;
}
```

### Rationale

- Validation runs at evaluation time (fast feedback)
- Clear, specific error messages with context
- Centralized validation logic in one place
- Security-focused: prevents uid 0, requires SSH keys

### Alternatives Considered

1. **Module options with type checking**: More idiomatic but requires restructuring all modules; consider for v2
2. **Runtime checks**: Rejected - fails too late in the process

---

## R4: FlakeHub Caching Behavior

### Question

Does `include-output-paths: true` in flakehub-push work for library flakes that export modules?

### Findings

#### FlakeHub Documentation

From Determinate Systems docs:
> `include-output-paths`: When true, the action resolves all flake outputs to store paths and includes them in the published flake. This allows consumers to fetch pre-built derivations.

#### What Gets Cached

- **nixosConfigurations**: The `system.build.toplevel` derivation and its dependencies
- **packages**: Direct package outputs
- **devShells**: Development shell derivations

#### What Doesn't Get Cached Directly

- **nixosModules**: These are functions, not derivations. They evaluate to derivations when consumed.
- **homeManagerModules**: Same - functions that produce derivations.

#### Effective Caching Strategy

For library flakes, the caching benefit comes from:
1. **Example configurations** built in CI populate the cache with common derivations
2. When consumers use similar module combinations, they hit the cache
3. The `nixpkgs` input is shared, so nixpkgs derivations are cached

### Decision

1. Keep `include-output-paths: true` in CI (already configured)
2. Build example configurations in CI to populate cache with common derivations
3. Document that consumers benefit from cache hits on shared dependencies

### Rationale

- No changes needed to existing CI configuration
- Example configurations serve dual purpose: CI validation + cache warming
- Consumer builds will be fast for nixpkgs packages; only consumer-specific config needs evaluation

### Alternatives Considered

1. **Separate cache for consumers**: Overkill for personal project; FlakeHub cache is sufficient

---

## Summary

| Research Task | Decision | Confidence |
|---------------|----------|------------|
| Module export patterns | Flat `nixosModules`/`homeManagerModules` with `default` | High |
| specialArgs propagation | `specialArgs` → NixOS, `extraSpecialArgs` → HM | High |
| Schema validation | `lib/schema.nix` with `assertMsg` chains | High |
| FlakeHub caching | Existing config sufficient; examples warm cache | High |

All research tasks resolved. No NEEDS CLARIFICATION items remain.