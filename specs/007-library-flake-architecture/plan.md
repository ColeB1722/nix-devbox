# Implementation Plan: Library-Style Flake Architecture

**Branch**: `007-library-flake-architecture` | **Date**: 2025-01-22 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/007-library-flake-architecture/spec.md`

## Summary

Transform nix-devbox from a monolithic NixOS configuration into a reusable library flake that exports modules (`nixosModules`, `homeManagerModules`) and host definitions. Consumers create minimal private repositories that import the public flake from FlakeHub, provide their personal user data and hardware configurations, and build complete NixOS systems. The public flake contains no personal data and can be tested independently via example configurations.

## Technical Context

**Language/Version**: Nix (flakes), NixOS 25.05  
**Primary Dependencies**: nixpkgs, home-manager, nixos-wsl, FlakeHub  
**Storage**: N/A (configuration-only, no runtime storage)  
**Testing**: `nix flake check`, `nix build` for example configurations  
**Target Platform**: NixOS (x86_64-linux, aarch64-linux)  
**Project Type**: Library flake (module exports + example configurations)  
**Performance Goals**: Consumer builds < 5 minutes with cached public modules  
**Constraints**: Pure Nix evaluation (no env var injection), security assertions non-overridable  
**Scale/Scope**: 2 host definitions (devbox, devbox-wsl), 8 NixOS modules, 4 HM modules, 2 HM profiles

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Declarative Configuration | ✅ PASS | All configuration remains in Nix expressions; no imperative steps |
| II. Headless-First Design | ✅ PASS | No changes to headless-first approach |
| III. Security by Default | ✅ PASS | Security assertions remain absolute and non-overridable per clarification |
| IV. Modular and Reusable | ✅ PASS | This feature *improves* modularity by enabling external consumption |
| V. Documentation as Code | ✅ PASS | FR-014/15/16 require documentation; example consumer flake serves as living doc |

**Gate Result**: PASS - All principles satisfied. Proceed to Phase 0.

## Project Structure

### Documentation (this feature)

```text
specs/007-library-flake-architecture/
├── spec.md              # Feature specification (complete)
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output (user data schema)
├── quickstart.md        # Phase 1 output (consumer setup guide)
├── contracts/           # Phase 1 output (module interfaces)
│   ├── nixos-modules.md
│   ├── hm-modules.md
│   └── user-data-schema.nix
└── tasks.md             # Phase 2 output
```

### Source Code (repository root - AFTER refactor)

```text
# Public flake structure (nix-devbox)
flake.nix                    # Exports nixosModules, homeManagerModules, hosts
lib/
├── schema.nix               # User data schema definition + validation
└── mkHost.nix               # Helper to compose host with consumer data

nixos/                       # NixOS modules (unchanged internally)
├── core.nix
├── ssh.nix
├── firewall.nix
├── tailscale.nix
├── docker.nix
├── fish.nix
├── users.nix                # MODIFIED: accepts `users` from specialArgs
└── code-server.nix          # MODIFIED: iterates over users for ports

home/
├── modules/                 # HM modules (unchanged internally)
│   ├── cli.nix
│   ├── fish.nix
│   ├── git.nix              # MODIFIED: accepts user email/gitUser from args
│   └── dev.nix
├── profiles/
│   ├── minimal.nix
│   └── developer.nix
└── users/                   # REMOVED (moved to consumer repos)

hosts/                       # Host DEFINITIONS (module compositions)
├── devbox/
│   └── default.nix          # MODIFIED: no hardware import, declares requirements
└── devbox-wsl/
    └── default.nix          # MODIFIED: no hardware import, declares requirements

examples/                    # NEW: Example configurations for CI + consumers
├── users.nix                # Example user data with placeholder values
├── hardware-example.nix     # Minimal hardware config for CI builds
└── consumer-flake/          # Complete example consumer repo
    ├── flake.nix
    ├── users.nix
    └── hardware/
        └── devbox.nix

docs/
├── LIBRARY-ARCHITECTURE.md  # NEW: Explains the public/private split
├── CONSUMER-QUICKSTART.md   # NEW: How to create a consumer repo
└── USER-DATA-SCHEMA.md      # NEW: Schema reference with examples
```

### Consumer Repository Structure (private, external)

```text
# Consumer's private flake (e.g., my-devbox-config)
flake.nix                    # Imports nix-devbox from FlakeHub
users.nix                    # Personal user data (emails, SSH keys)
hardware/
├── devbox.nix               # Machine-specific hardware-configuration.nix
└── devbox-wsl.nix           # WSL-specific settings (if applicable)
```

**Structure Decision**: Library flake pattern. Public repo exports modules; consumers compose in private repos. Example configurations in `examples/` enable CI testing without personal data.

## Phase 0: Research

### Research Tasks

1. **Nix module export patterns**: How do established library flakes (nixos-hardware, nix-darwin, sops-nix) structure their exports?
2. **specialArgs propagation**: Best practices for passing consumer data through nixosSystem → modules → Home Manager
3. **Nix assertions for schema validation**: How to produce clear error messages for missing/invalid user data fields
4. **FlakeHub caching behavior**: Confirm include-output-paths works as expected for library flakes

### Findings

#### R1: Module Export Patterns

**Decision**: Export modules as attribute sets under `nixosModules` and `homeManagerModules` outputs.

**Rationale**: This is the standard pattern used by:
- `nixos-hardware`: `nixosModules.common-cpu-intel`
- `sops-nix`: `nixosModules.sops`
- `home-manager`: `nixosModules.home-manager`

**Implementation**:
```nix
outputs = { ... }: {
  nixosModules = {
    core = import ./nixos/core.nix;
    ssh = import ./nixos/ssh.nix;
    # ... etc
    default = { imports = [ ./nixos/core.nix ./nixos/ssh.nix /* all */ ]; };
  };
  homeManagerModules = {
    cli = import ./home/modules/cli.nix;
    # ... etc
    profiles.developer = import ./home/profiles/developer.nix;
  };
};
```

#### R2: specialArgs Propagation

**Decision**: Consumer passes `users` attrset via `specialArgs`; modules access via function argument.

**Rationale**: `specialArgs` is the standard mechanism for passing extra arguments to NixOS modules. Home Manager receives these via `extraSpecialArgs`.

**Implementation**:
```nix
# Consumer's flake.nix
nixosConfigurations.devbox = nixpkgs.lib.nixosSystem {
  specialArgs = { 
    users = import ./users.nix; 
  };
  modules = [ ... ];
};

# Public module (nixos/users.nix)
{ config, pkgs, users, ... }:  # `users` comes from specialArgs
{
  users.users = lib.mapAttrs (name: u: { ... }) users;
}
```

#### R3: Schema Validation with Assertions

**Decision**: Use NixOS assertions with descriptive messages; validate at module evaluation time.

**Rationale**: Assertions halt evaluation with clear messages. Combined with `lib.assertMsg`, we can provide actionable migration instructions.

**Implementation**:
```nix
# lib/schema.nix
{ lib }:
{
  validateUser = name: user: 
    lib.assertMsg (user ? uid) "User '${name}' missing required field 'uid'" &&
    lib.assertMsg (user.uid >= 1000) "User '${name}' uid must be >= 1000 (got ${toString user.uid})" &&
    lib.assertMsg (user ? sshKeys && user.sshKeys != []) "User '${name}' must have at least one SSH key";
    # ... more validations
}
```

#### R4: FlakeHub Caching

**Decision**: Use `include-output-paths: true` in flakehub-push; consumers benefit from cached derivations.

**Rationale**: FlakeHub documentation confirms this caches resolved store paths. Consumer builds fetch pre-built derivations for public modules.

**Implementation**: No code changes needed; existing CI already uses this flag.

## Phase 1: Design & Contracts

### Data Model: User Data Schema

See [data-model.md](./data-model.md) for full schema.

**Summary**:
```nix
# Required structure for consumer's users.nix
{
  # Per-user records (at least one required)
  <username> = {
    name = "<username>";           # string, must match attrset key
    uid = <1000-65533>;            # int, not 0, not in system range
    description = "<string>";      # non-empty string
    email = "<email>";             # non-empty string
    gitUser = "<github-username>"; # non-empty string
    isAdmin = <bool>;              # true = wheel group
    sshKeys = [ "<pubkey>" ... ];  # non-empty list of valid SSH public keys
    extraGroups = [ ... ];         # optional, list of strings
  };
  # ...more users...

  # Collection fields (derived from user records)
  allUserNames = [ "<username1>" "<username2>" ... ];
  adminUserNames = [ "<username>" ... ];  # users where isAdmin = true
  
  # Service configuration
  codeServerPorts = {
    <username> = <port>;  # 8080-8099 recommended range
  };
}
```

### Module Interfaces

See [contracts/nixos-modules.md](./contracts/nixos-modules.md) for full interface definitions.

**Key Changes**:

| Module | Current | After Refactor |
|--------|---------|----------------|
| `nixos/users.nix` | Imports `../lib/users.nix` directly | Accepts `users` via function arg from `specialArgs` |
| `nixos/code-server.nix` | Hardcoded user list | Iterates `users.allUserNames`, uses `users.codeServerPorts` |
| `home/modules/git.nix` | Imports user data | Accepts `userEmail`, `userGitName` via `extraSpecialArgs` |
| `hosts/*/default.nix` | Imports hardware file | Declares hardware as required; consumer provides |

### Host Definition Interface

Hosts become "templates" that declare their requirements:

```nix
# hosts/devbox/default.nix (after refactor)
{ config, lib, pkgs, users, ... }:

{
  imports = [
    ../../nixos/core.nix
    ../../nixos/ssh.nix
    ../../nixos/firewall.nix
    ../../nixos/tailscale.nix
    ../../nixos/docker.nix
    ../../nixos/fish.nix
    ../../nixos/users.nix
    ../../nixos/code-server.nix
  ];

  # Declare that hardware config is REQUIRED but not provided here
  # Consumer must include their hardware module
  
  networking.hostName = lib.mkDefault "devbox";
  devbox.tailscale.enable = lib.mkDefault true;
}
```

### Consumer Interface

See [contracts/consumer-interface.md](./contracts/consumer-interface.md).

**Minimal Consumer Flake** (~40 lines):
```nix
{
  inputs = {
    nix-devbox.url = "https://flakehub.com/f/coal-bap/nix-devbox/*";
    nixpkgs.follows = "nix-devbox/nixpkgs";
    home-manager.follows = "nix-devbox/home-manager";
  };

  outputs = { self, nix-devbox, nixpkgs, home-manager, ... }:
  let
    users = import ./users.nix;
  in {
    nixosConfigurations.devbox = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit users; };
      modules = [
        nix-devbox.nixosModules.default  # All NixOS modules
        nix-devbox.hosts.devbox          # Host definition
        ./hardware/devbox.nix            # Consumer's hardware
        home-manager.nixosModules.home-manager
        {
          home-manager.extraSpecialArgs = { inherit users; };
          home-manager.users = builtins.listToAttrs (map (name: {
            inherit name;
            value = { imports = [ nix-devbox.homeManagerModules.profiles.developer ]; };
          }) users.allUserNames);
        }
      ];
    };
  };
}
```

## Implementation Phases

### Phase A: Schema & Validation (Foundation)

1. Create `lib/schema.nix` with user data validation functions
2. Create `examples/users.nix` with placeholder data
3. Create `examples/hardware-example.nix` for CI builds

### Phase B: Module Refactoring

1. Modify `nixos/users.nix` to accept `users` from `specialArgs`
2. Modify `nixos/code-server.nix` to iterate over `users.allUserNames`
3. Modify `home/modules/git.nix` to accept user config via args
4. Update Home Manager integration to pass user data

### Phase C: Flake Output Structure

1. Add `nixosModules` output with individual + default modules
2. Add `homeManagerModules` output with modules + profiles
3. Add `hosts` output exposing host definitions
4. Update existing `nixosConfigurations` to use example data for CI

### Phase D: Example Consumer & Documentation

1. Create `examples/consumer-flake/` with complete working example
2. Write `docs/LIBRARY-ARCHITECTURE.md`
3. Write `docs/CONSUMER-QUICKSTART.md`
4. Write `docs/USER-DATA-SCHEMA.md`

### Phase E: CI & Validation

1. Update CI to build example configurations (no personal data)
2. Add CI check that public repo contains no personal data
3. Test FlakeHub publish with new structure
4. Verify consumer example builds successfully

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Breaking existing deployments | Medium | High | Maintain `nixosConfigurations` with example data; document migration |
| Complex consumer setup | Medium | Medium | Provide complete example + detailed quickstart |
| Schema validation too strict | Low | Medium | Start with security-critical validations only; expand later |
| FlakeHub caching issues | Low | Low | Falls back to source evaluation; acceptable |

## Complexity Tracking

No constitution violations requiring justification. The refactor improves alignment with Principle IV (Modular and Reusable).

## Post-Design Constitution Re-Check

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Declarative Configuration | ✅ PASS | No changes |
| II. Headless-First Design | ✅ PASS | No changes |
| III. Security by Default | ✅ PASS | Assertions remain absolute; validation adds security |
| IV. Modular and Reusable | ✅ IMPROVED | Modules now consumable externally |
| V. Documentation as Code | ✅ PASS | New docs added; examples serve as living documentation |

**Final Gate Result**: PASS - Proceed to Phase 2 (task breakdown via `/speckit.tasks`).