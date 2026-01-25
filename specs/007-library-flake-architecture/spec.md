# Feature Specification: Library-Style Flake Architecture

**Feature Branch**: `007-library-flake-architecture`  
**Created**: 2025-01-22  
**Status**: Draft  
**Input**: User description: "Refactor nix-devbox into a library-style flake architecture that exports reusable modules, enabling private consumer repos to provide user data and hardware configurations while the public flake contains infrastructure definitions"

## Overview

Transform nix-devbox from a monolithic NixOS configuration into a reusable library flake that exports modules and host definitions. This enables a clean separation where the public repository contains infrastructure definitions (modules, profiles, host structures) while personal data (user information, SSH keys, hardware configurations) lives in private consumer repositories.

This architecture provides:
- **Shareability**: The public flake becomes a "devbox distribution" anyone can use
- **Privacy**: Personal data never enters version control in the public repo
- **Cacheability**: FlakeHub caches the public modules; consumers only build their private additions
- **Purity**: No environment variable injection or template preprocessing - pure Nix throughout

## Clarifications

### Session 2025-01-22

- Q: How should the system handle user data schema changes between public flake versions? → A: Informative - Schema changes cause build errors with clear migration instructions
- Q: How should the system behave when FlakeHub is unavailable during a consumer build? → A: Standard Nix behavior - rely on local Nix store cache; fail if cache miss and FlakeHub unavailable
- Q: What level of validation should be applied to user data values (beyond checking for missing fields)? → A: Security-focused - validate uid ranges (not 0, not system range), SSH key format, and non-empty required strings
- Q: What happens when consumer-provided settings conflict with public module security assertions? → A: Assertions are absolute - public module security assertions (SSH hardening, firewall, etc.) always apply and cannot be overridden; consumer isAdmin only controls wheel/sudo group membership
- Q: Should the library architecture support multiple users per consumer configuration? → A: Multi-user supported - consumers can define multiple users; host definitions iterate over all provided users

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Consumer Creates Private Configuration (Priority: P1)

A user wants to use nix-devbox as a base for their own development machine. They create a minimal private repository that imports the public flake from FlakeHub, provides their personal user data (name, email, SSH keys), and adds their machine's hardware configuration. They can then build and deploy a complete NixOS system.

**Why this priority**: This is the core value proposition - enabling users to consume the public flake while keeping personal data private. Without this working, the architecture serves no purpose.

**Independent Test**: A new user can create a private flake with ~50 lines of configuration, reference nix-devbox from FlakeHub, and successfully build a bootable NixOS system with their personal settings.

**Acceptance Scenarios**:

1. **Given** a user has a private repository with their user data and hardware config, **When** they run `nix build .#nixosConfigurations.devbox.config.system.build.toplevel`, **Then** the build succeeds and incorporates their personal settings with the public modules.

2. **Given** a user references nix-devbox via FlakeHub URL, **When** they build their configuration, **Then** the public modules are fetched from FlakeHub cache (not rebuilt locally).

3. **Given** a user provides incomplete user data (missing required fields), **When** they attempt to build, **Then** they receive a clear error indicating which fields are missing.

---

### User Story 2 - Maintainer Publishes Module Updates (Priority: P2)

The nix-devbox maintainer improves a module (e.g., adds a new CLI tool to the dev profile). They push to the public repository, CI validates and publishes to FlakeHub. Consumers can update their flake inputs to receive the improvement without changing their private configuration.

**Why this priority**: Enables the public/private separation to actually work over time. Consumers need to receive updates without merge conflicts in their personal data.

**Independent Test**: A module change in the public repo flows through CI to FlakeHub, and a consumer running `nix flake update` receives the change.

**Acceptance Scenarios**:

1. **Given** a maintainer pushes a module change to main, **When** CI completes, **Then** the updated flake is published to FlakeHub with the new modules.

2. **Given** a consumer has an existing private configuration, **When** they run `nix flake update nix-devbox`, **Then** they receive the latest modules without any changes to their private files.

3. **Given** the public flake is updated, **When** a consumer rebuilds, **Then** FlakeHub cache provides pre-built public derivations and only private additions require local evaluation.

---

### User Story 3 - New User Bootstraps from Example (Priority: P2)

A new user discovers nix-devbox and wants to try it. They find a documented example/template for creating their private consumer repository. They copy the example, fill in their personal details, and have a working configuration within minutes.

**Why this priority**: Reduces adoption friction. Without clear examples, users won't understand how to consume the library flake.

**Independent Test**: A user with no prior nix-devbox experience can follow documentation to create a working private configuration in under 15 minutes.

**Acceptance Scenarios**:

1. **Given** a user reads the consumer documentation, **When** they follow the quickstart guide, **Then** they have a buildable private configuration with placeholder values replaced.

2. **Given** an example consumer flake exists in the public repo, **When** a user copies and modifies it, **Then** it builds successfully with their personal data.

---

### User Story 4 - Maintainer Tests Public Flake Independently (Priority: P3)

The maintainer needs to validate that the public flake's modules work correctly without requiring personal data. The public repository includes example/test configurations that can be built in CI to verify module correctness.

**Why this priority**: Ensures CI can validate the public flake without exposing or requiring personal data. Enables confident refactoring.

**Independent Test**: CI can run `nix flake check` and build example configurations without any external data or secrets.

**Acceptance Scenarios**:

1. **Given** the public repository has example configurations with placeholder users, **When** CI runs `nix flake check`, **Then** all checks pass without requiring external variables.

2. **Given** a maintainer modifies a NixOS module, **When** they run `just check` locally, **Then** they receive feedback on module correctness without needing their private repo.

---

### Edge Cases

- What happens when a consumer provides a user with `isAdmin = true` but the public module's security assertions are stricter? **→ Security assertions are absolute and non-negotiable. The isAdmin flag only controls wheel group membership (sudo access), not the ability to bypass security policies like SSH hardening or firewall rules. Consumers who need different security must fork the public modules.**
- How does the system handle version mismatches between public flake expectations and consumer-provided data schema? **→ Build fails with informative error message explaining required schema changes and migration steps.**
- What happens when a consumer references a host definition that doesn't exist in the public flake?
- How does the system behave when FlakeHub is unavailable during a consumer build? **→ Standard Nix behavior applies: local store cache is used if available; otherwise build fails. Documentation should note that consumers can temporarily switch to GitHub URL as fallback.**

## Requirements *(mandatory)*

### Functional Requirements

#### Module Export Requirements

- **FR-001**: The public flake MUST export all NixOS modules individually via `nixosModules` output (e.g., `nixosModules.core`, `nixosModules.ssh`, `nixosModules.tailscale`)
- **FR-002**: The public flake MUST export all Home Manager modules individually via `homeManagerModules` output
- **FR-003**: The public flake MUST export Home Manager profiles via `homeManagerModules` (e.g., `homeManagerModules.profiles.developer`)
- **FR-004**: The public flake MUST export host definitions that can be composed with consumer-provided data

#### Consumer Interface Requirements

- **FR-005**: Consumer flakes MUST be able to pass user data via `specialArgs` to NixOS modules
- **FR-006**: NixOS modules MUST accept a `users` argument containing user definitions and use it to create system users
- **FR-007**: Home Manager modules MUST accept user-specific configuration (email, git username) via module arguments
- **FR-008**: The system MUST provide clear error messages when required user data fields are missing
- **FR-018**: The system MUST validate user data values for security-critical fields: uid must not be 0 or in system range (1-999), SSH keys must match valid format, required string fields must be non-empty
- **FR-019**: Security assertions in public modules (SSH hardening, firewall enabled, no root login) MUST be non-overridable by consumer configurations; the isAdmin user flag MUST only control wheel group membership
- **FR-020**: The system MUST support multiple users per consumer configuration; host definitions MUST iterate over all users provided in consumer's user data to create accounts, Home Manager configurations, and per-user services (e.g., code-server)

#### Data Schema Requirements

- **FR-009**: The public flake MUST define and document the expected schema for user data (required fields per user: name, uid, email, gitUser, isAdmin, sshKeys; required collection fields: allUserNames, adminUserNames)
- **FR-010**: The public flake MUST define and document the expected interface for hardware configurations
- **FR-011**: Host definitions MUST declare their dependencies on user data and hardware configuration explicitly
- **FR-017**: When user data schema changes between versions, the system MUST produce build-time errors with clear migration instructions indicating what changed and how to update consumer configurations

#### Backward Compatibility Requirements

- **FR-012**: The public flake MUST continue to support direct use for development/testing with example configurations
- **FR-013**: Existing CI workflows MUST continue to function using example/placeholder configurations

#### Documentation Requirements

- **FR-014**: The public repository MUST include documentation explaining the library architecture
- **FR-015**: The public repository MUST include an example consumer flake that demonstrates proper usage
- **FR-016**: The public repository MUST document the user data schema with examples

### Key Entities

- **NixOS Module**: A reusable configuration unit that configures one aspect of the system (e.g., SSH, Tailscale). Accepts `users` data from consumer. Exported via `nixosModules`.

- **Home Manager Module**: A reusable user-environment configuration (e.g., CLI tools, git config). Accepts user-specific settings. Exported via `homeManagerModules`.

- **Host Definition**: A composition of NixOS modules that defines a type of machine (e.g., devbox, devbox-wsl). Requires user data and hardware config from consumer.

- **User Data**: Consumer-provided structure containing personal information (name, uid, email, SSH keys, admin status). Passed via `specialArgs`.

- **Consumer Flake**: A private flake that imports the public library, provides user data and hardware configuration, and produces complete NixOS configurations.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A new consumer can create a working private configuration with fewer than 100 lines of Nix code (excluding hardware-configuration.nix)

- **SC-002**: Consumer builds that reference FlakeHub complete in under 5 minutes on a standard machine (assuming cached public modules)

- **SC-003**: The public repository contains zero personal data (emails, SSH keys, hardware UUIDs) after migration

- **SC-004**: All existing host configurations (devbox, devbox-wsl) continue to build successfully via example configurations in CI

- **SC-005**: Module changes in the public flake can be consumed by updating flake inputs alone, with no changes required to consumer's private files (assuming no breaking schema changes)

- **SC-006**: Documentation enables a user unfamiliar with the project to create a working consumer configuration within 15 minutes

## Assumptions

- FlakeHub supports the `include-output-paths` feature for caching resolved derivations
- Consumers have basic familiarity with Nix flakes (can create a flake.nix, run nix build)
- The user data schema is stable enough that breaking changes will be rare
- Consumers will use Git for their private repositories (though any storage works)

## Out of Scope

- Automatic migration tooling for existing users (manual migration is acceptable)
- GUI or interactive tooling for creating consumer configurations
- Support for non-NixOS platforms in this iteration (Darwin support is a future enhancement)
- Secrets management integration (consumers handle their own secrets via agenix/sops-nix in their private repos)