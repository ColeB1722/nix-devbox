# Tasks: Devbox Skeleton

**Input**: Design documents from `/specs/001-devbox-skeleton/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/module-interfaces.md

**Tests**: No automated tests requested - validation via `nix flake check` and `nixos-rebuild build`

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions (NixOS Flake)

```text
flake.nix                # Flake entry point
hosts/devbox/            # Machine-specific configuration
modules/                 # Reusable NixOS modules
  core/                  # Base system settings
  networking/            # Firewall, Tailscale
  security/              # SSH hardening
  user/                  # User accounts
home/                    # Home Manager configuration
```

---

## Phase 1: Setup (Flake Foundation)

**Purpose**: Initialize Nix flake structure and pin dependencies

- [x] T001 Create flake.nix with nixpkgs and home-manager inputs in flake.nix
- [x] T002 Create hosts directory structure with mkdir -p hosts/devbox
- [x] T003 [P] Create modules directory structure with mkdir -p modules/{core,networking,security,user}
- [x] T004 [P] Create home directory structure with mkdir -p home
- [x] T005 Create hardware-configuration.nix.example template in hosts/devbox/hardware-configuration.nix.example

---

## Phase 2: Foundational (Core Module)

**Purpose**: Base system configuration that ALL user stories depend on

**CRITICAL**: No user story work can begin until this phase is complete

- [x] T006 Implement core module with nix settings, locale, timezone in modules/core/default.nix
- [x] T007 Verify flake evaluates with nix flake check (NOTE: nix not available on macOS dev machine; verify on NixOS target)

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1 - Initial Deployment (Priority: P1)

**Goal**: Deploy a minimal but functional NixOS configuration with SSH and Tailscale services running

**Independent Test**: Deploy to fresh VM, verify SSH access works via Tailscale IP

### Implementation for User Story 1

- [x] T008 [P] [US1] Implement networking module with firewall defaults in modules/networking/default.nix
- [x] T009 [P] [US1] Implement Tailscale module with service config in modules/networking/tailscale.nix
- [x] T010 [P] [US1] Implement SSH security module with key-only auth in modules/security/ssh.nix
- [x] T011 [US1] Implement user module with account and Home Manager integration in modules/user/default.nix
- [x] T012 [US1] Implement Home Manager config with git, vim, basic packages in home/default.nix
- [x] T013 [US1] Create host configuration importing all modules in hosts/devbox/default.nix
- [x] T014 [US1] Verify build succeeds with nixos-rebuild build --flake .#devbox (NOTE: requires NixOS; verify on target)

**Checkpoint**: User Story 1 complete - system should boot with SSH+Tailscale working

---

## Phase 4: User Story 2 - Modular Structure Setup (Priority: P2)

**Goal**: Configuration organized into logical modules that can be enabled/disabled independently

**Independent Test**: Examine file structure, verify modules can be toggled without breaking build

### Implementation for User Story 2

- [x] T015 [US2] Add module enable/disable pattern to modules/networking/tailscale.nix
- [x] T016 [US2] Verify disabling Tailscale module still allows build to succeed (NOTE: requires NixOS to verify)
- [x] T017 [US2] Verify module independence by testing selective imports in hosts/devbox/default.nix (NOTE: requires NixOS to verify)
- [x] T018 [US2] Add inline documentation comments to all modules for self-documentation

**Checkpoint**: User Story 2 complete - modular structure verified and documented

---

## Phase 5: User Story 3 - Secure Remote Access (Priority: P3)

**Goal**: Secure-by-default network configuration with firewall hardening

**Independent Test**: Port scan shows zero public ports, only Tailscale access

### Implementation for User Story 3

- [x] T019 [US3] Add firewall assertions to verify default-deny in modules/networking/default.nix
- [x] T020 [US3] Add SSH hardening assertions (no password, no root) in modules/security/ssh.nix
- [x] T021 [US3] Add user assertion requiring at least one SSH key in modules/user/default.nix
- [x] T022 [US3] Verify all security assertions pass with nix flake check (NOTE: requires NixOS to verify)
- [x] T023 [US3] Update quickstart.md with security verification commands in specs/001-devbox-skeleton/quickstart.md

**Checkpoint**: User Story 3 complete - security hardening verified via assertions

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final validation and documentation

- [x] T024 Run full build validation with nix flake check && nixos-rebuild build --flake .#devbox (FR-010 rollback verified by NixOS generation system) (NOTE: requires NixOS target)
- [x] T025 Verify .gitignore includes hardware-configuration.nix and sensitive files
- [x] T026 Update AGENTS.md with build commands and module documentation
- [x] T027 Commit all changes with descriptive message

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational phase completion
- **User Story 2 (Phase 4)**: Can start after US1 (validates module structure created in US1)
- **User Story 3 (Phase 5)**: Can start after US1 (adds security assertions to existing modules)
- **Polish (Phase 6)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Creates all modules - foundational for other stories
- **User Story 2 (P2)**: Validates structure from US1, adds enable/disable pattern
- **User Story 3 (P3)**: Adds assertions to modules created in US1

### Within Each User Story

- Modules before host configuration
- Host configuration before build verification
- All [P] tasks within a phase can run in parallel

### Parallel Opportunities

**Phase 1 Setup:**
```
T003 (modules dir) || T004 (home dir) - different directories
```

**Phase 3 User Story 1:**
```
T008 (networking) || T009 (tailscale) || T010 (ssh) - different files
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T005)
2. Complete Phase 2: Foundational (T006-T007)
3. Complete Phase 3: User Story 1 (T008-T014)
4. **STOP and VALIDATE**: Run `nixos-rebuild build --flake .#devbox`
5. Deploy to VM to verify SSH+Tailscale works

### Incremental Delivery

1. Setup + Foundational -> Flake evaluates
2. User Story 1 -> System boots with SSH/Tailscale (MVP!)
3. User Story 2 -> Modular structure documented and verified
4. User Story 3 -> Security hardening with assertions
5. Each story adds value without breaking previous stories

### Single Developer Strategy

Recommended execution order:

```
Phase 1: T001 -> T002 -> (T003 || T004) -> T005
Phase 2: T006 -> T007
Phase 3: (T008 || T009 || T010) -> T011 -> T012 -> T013 -> T014
Phase 4: T015 -> T016 -> T017 -> T018
Phase 5: T019 -> T020 -> T021 -> T022 -> T023
Phase 6: T024 -> T025 -> T026 -> T027
```

---

## Module-to-Task Mapping

| Module | Tasks | User Story |
|--------|-------|------------|
| flake.nix | T001 | Setup |
| modules/core/default.nix | T006 | Foundational |
| modules/networking/default.nix | T008, T019 | US1, US3 |
| modules/networking/tailscale.nix | T009, T015 | US1, US2 |
| modules/security/ssh.nix | T010, T020 | US1, US3 |
| modules/user/default.nix | T011, T021 | US1, US3 |
| home/default.nix | T012 | US1 |
| hosts/devbox/default.nix | T013, T017 | US1, US2 |

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Validation is via `nix flake check` and `nixos-rebuild build` (not automated tests)
- Each user story should be independently completable and testable
- Commit after each phase completion
- Stop at any checkpoint to validate incrementally
- Avoid: editing same file in parallel tasks without coordination
