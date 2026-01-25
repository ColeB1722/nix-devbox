# Tasks: Library-Style Flake Architecture

**Input**: Design documents from `/specs/007-library-flake-architecture/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, contracts/ ✅

**Tests**: Not explicitly requested in specification. Tasks focus on implementation with validation via `nix flake check` and `nix build`.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4)
- Include exact file paths in descriptions

## Path Conventions

- **Nix modules**: `nixos/`, `home/modules/`, `home/profiles/`
- **Library functions**: `lib/`
- **Host definitions**: `hosts/`
- **Examples**: `examples/`
- **Documentation**: `docs/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create foundational schema validation and example data structures

- [x] T001 Create `lib/schema.nix` with user data validation functions (validateUser, validateUsers, assertMsg chains for uid, sshKeys, required fields)
- [x] T002 [P] Create `examples/users.nix` with placeholder user data (exampleuser, uid=1000, placeholder SSH key, all required fields)
- [x] T003 [P] Create `examples/hardware-example.nix` with minimal hardware config for CI builds (boot loader, dummy filesystem mounts)
- [x] T004 Create `lib/mkHost.nix` helper function to compose host definitions with consumer data

---

## Phase 2: Foundational (Module Refactoring)

**Purpose**: Modify existing modules to accept user data from `specialArgs` instead of importing directly

**⚠️ CRITICAL**: These changes are blocking - all modules must accept `users` argument before flake outputs can be restructured

- [x] T005 Modify `nixos/users.nix` to accept `users` argument from `specialArgs` and iterate over `users.allUserNames` to create accounts
- [x] T006 [P] Modify `nixos/code-server.nix` to iterate over `users.allUserNames` and use `users.codeServerPorts` for port assignments
- [x] T007 [P] Modify `home/modules/git.nix` to accept user-specific `userEmail` and `userGitName` via module arguments (NOTE: No changes needed - git config is set via nixos/users.nix HM integration)
- [x] T008 Modify `hosts/devbox/default.nix` to remove hardware import and accept `users` argument; use `lib.mkDefault` for overridable settings
- [x] T009 [P] Modify `hosts/devbox-wsl/default.nix` to remove hardware import and accept `users` argument; use `lib.mkDefault` for overridable settings
- [x] T010 Remove `home/users/coal.nix` (personal data moves to consumer repo)
- [x] T011 [P] Remove `home/users/violino.nix` (personal data moves to consumer repo)
- [x] T012 Remove `lib/users.nix` (replaced by consumer-provided users.nix)
- [x] T013 Update Home Manager integration in `nixos/users.nix` to pass `users` via `extraSpecialArgs` and dynamically create HM configs for all users

**Additional fixes during Phase 2**:
- [x] Updated `nixos/docker.nix` to use dynamic user assertions instead of hardcoded user names
- [x] Updated `home/profiles/developer.nix` and `minimal.nix` to use `lib.mkDefault` for `home.stateVersion`
- [x] Removed `system.stateVersion` from `nixos/core.nix` (should be set by hardware/host config)
- [x] Fixed `examples/hardware-example.nix` to use GRUB (matching core.nix defaults) instead of systemd-boot

**Checkpoint**: All modules now accept user data via arguments; no direct imports of personal data

---

## Phase 3: User Story 1 - Consumer Creates Private Configuration (Priority: P1) 🎯 MVP

**Goal**: Enable consumers to create private repos that import the public flake and provide their own user/hardware data

**Independent Test**: Run `nix build` on the example consumer flake to verify it produces a bootable NixOS configuration

### Implementation for User Story 1

- [x] T014 [US1] Add `nixosModules` output to `flake.nix` exporting individual modules (core, ssh, firewall, tailscale, docker, fish, users, code-server) plus `default` combining all
- [x] T015 [US1] Add `homeManagerModules` output to `flake.nix` exporting individual modules (cli, fish, git, dev) and nested `profiles` (minimal, developer)
- [x] T016 [US1] Add `hosts` output to `flake.nix` exposing host definitions (devbox, devbox-wsl) as importable modules
- [x] T017 [US1] Update `nixosConfigurations.devbox` in `flake.nix` to use `examples/users.nix` and `examples/hardware-example.nix` via `specialArgs`
- [x] T018 [P] [US1] Update `nixosConfigurations.devbox-wsl` in `flake.nix` to use `examples/users.nix` via `specialArgs`
- [x] T019 [US1] Integrate `lib/schema.nix` validation into `nixos/users.nix` using assertions to validate consumer-provided user data at evaluation time
- [x] T020 [US1] Verify build succeeds: `nix flake check --no-build` passes for devbox configuration
- [x] T021 [US1] Verify build succeeds: `nix flake check --no-build` passes for devbox-wsl configuration

**Checkpoint**: Public flake exports modules and builds with example data; ready for consumer testing

---

## Phase 4: User Story 4 - Maintainer Tests Public Flake Independently (Priority: P3, but needed for CI)

**Goal**: Ensure CI can validate the public flake without personal data

**Independent Test**: `nix flake check` passes; CI builds example configurations successfully

**Note**: Implementing US4 before US2/US3 because CI validation is needed to verify US1 works correctly

### Implementation for User Story 4

- [ ] T022 [US4] Verify `nix flake check` passes with refactored modules and example data
- [ ] T023 [US4] Update `.github/workflows/ci.yml` to ensure CI builds use example configurations (no changes may be needed if T017/T018 are correct)
- [ ] T024 [P] [US4] Add CI validation step to check that `lib/users.nix` does not exist (ensures no personal data in public repo)
- [ ] T025 [P] [US4] Add CI validation step to check that `home/users/` directory is empty or removed
- [ ] T026 [US4] Run `just check` locally to verify maintainer workflow works without private repo

**Checkpoint**: CI passes; public flake can be validated independently

---

## Phase 5: User Story 3 - New User Bootstraps from Example (Priority: P2)

**Goal**: Provide complete example consumer repo and documentation for new users

**Independent Test**: Copy `examples/consumer-flake/`, modify `users.nix` with test data, run `nix build` successfully

### Implementation for User Story 3

- [ ] T027 [US3] Create `examples/consumer-flake/` directory structure
- [ ] T028 [US3] Create `examples/consumer-flake/flake.nix` with complete working consumer configuration (~50 lines, references FlakeHub URL)
- [ ] T029 [P] [US3] Create `examples/consumer-flake/users.nix` with example user data and comments explaining each field
- [ ] T030 [P] [US3] Create `examples/consumer-flake/hardware/devbox.nix` with commented example hardware configuration
- [ ] T031 [US3] Verify example consumer flake builds: `cd examples/consumer-flake && nix build .#nixosConfigurations.devbox.config.system.build.toplevel`
- [ ] T032 [P] [US3] Create `docs/LIBRARY-ARCHITECTURE.md` explaining public/private split, module exports, consumer interface
- [ ] T033 [P] [US3] Create `docs/CONSUMER-QUICKSTART.md` with step-by-step guide (copy from `specs/007-library-flake-architecture/quickstart.md`, adapt for final paths)
- [ ] T034 [P] [US3] Create `docs/USER-DATA-SCHEMA.md` with complete schema reference and examples (copy from `specs/007-library-flake-architecture/data-model.md`, adapt)
- [ ] T035 [US3] Update `README.md` to document library architecture and link to new docs

**Checkpoint**: New users can follow docs to create working consumer config in <15 minutes

---

## Phase 6: User Story 2 - Maintainer Publishes Module Updates (Priority: P2)

**Goal**: Verify CI publishes to FlakeHub correctly and consumers can update

**Independent Test**: Push change to main, verify FlakeHub publish completes, verify consumer can run `nix flake update`

### Implementation for User Story 2

- [ ] T036 [US2] Review `.github/workflows/ci.yml` publish job configuration (should need no changes if using existing flakehub-push action)
- [ ] T037 [US2] Verify `include-output-paths: true` is set in flakehub-push action (enables caching)
- [ ] T038 [US2] Create test branch, push to release/*, verify CI builds and caches
- [ ] T039 [US2] Merge to main, verify FlakeHub publish succeeds
- [ ] T040 [US2] From example consumer flake, run `nix flake update` and verify new version is fetched

**Checkpoint**: CI pipeline publishes to FlakeHub; consumers can update seamlessly

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Final cleanup, validation, and documentation improvements

- [ ] T041 [P] Update `AGENTS.md` to document new library architecture and consumer workflow
- [ ] T042 [P] Update `justfile` with new targets if needed (e.g., `just build-example` for consumer flake)
- [ ] T043 Run full `nix flake check` and fix any remaining issues
- [ ] T044 [P] Add inline comments to `flake.nix` explaining module exports structure
- [ ] T045 Verify SC-001: Consumer config is <100 lines (check `examples/consumer-flake/flake.nix` + `users.nix`)
- [ ] T046 Verify SC-003: Public repo contains zero personal data (grep for old emails/SSH keys)
- [ ] T047 [P] Create `examples/consumer-flake/README.md` with usage instructions
- [ ] T048 Final review: Ensure all FR-* requirements from spec.md are addressed

---

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1 (Setup)
    │
    ▼
Phase 2 (Foundational) ──── BLOCKS ALL USER STORIES
    │
    ├──────────────────────────────────────┐
    ▼                                      ▼
Phase 3 (US1: Consumer Config)      Phase 4 (US4: CI Testing)
    │                                      │
    └──────────────┬───────────────────────┘
                   ▼
            Phase 5 (US3: Examples & Docs)
                   │
                   ▼
            Phase 6 (US2: FlakeHub Publish)
                   │
                   ▼
            Phase 7 (Polish)
```

### User Story Dependencies

- **User Story 1 (P1)**: Depends on Phase 2 completion. Core functionality - must complete first.
- **User Story 4 (P3)**: Depends on US1. Validates CI works before documenting for users.
- **User Story 3 (P2)**: Depends on US1 and US4. Documentation requires working implementation.
- **User Story 2 (P2)**: Depends on US3. FlakeHub publish testing requires example consumer.

### Within Each Phase

- Tasks marked [P] can run in parallel
- T005-T013 (Phase 2) can mostly run in parallel after T001
- Validation tasks (T020, T021, T026, T031) must run after their dependencies

### Parallel Opportunities

**Phase 1** (all can run in parallel after starting):
- T001 (schema) → T002, T003, T004 can run in parallel

**Phase 2** (after T005):
- T006, T007, T008, T009, T010, T011 can all run in parallel
- T012, T013 after T010/T011

**Phase 3-6**:
- Tasks marked [P] within each phase can run in parallel
- Different phases are sequential due to dependencies

---

## Parallel Example: Phase 2 (Foundational)

```bash
# After T005 (users.nix) completes, launch in parallel:
Task: "T006 [P] Modify nixos/code-server.nix..."
Task: "T007 [P] Modify home/modules/git.nix..."
Task: "T008 Modify hosts/devbox/default.nix..."
Task: "T009 [P] Modify hosts/devbox-wsl/default.nix..."
Task: "T010 Remove home/users/coal.nix..."
Task: "T011 [P] Remove home/users/violino.nix..."
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T004)
2. Complete Phase 2: Foundational (T005-T013)
3. Complete Phase 3: User Story 1 (T014-T021)
4. **STOP and VALIDATE**: `nix build` and `nix flake check` pass
5. At this point, the library architecture is functional

### Incremental Delivery

1. **MVP (Phases 1-3)**: Library exports work, builds with example data
2. **+CI Validation (Phase 4)**: CI confirms public flake is clean
3. **+Documentation (Phase 5)**: New users can onboard
4. **+FlakeHub (Phase 6)**: Full publish pipeline verified
5. **+Polish (Phase 7)**: Production-ready

### Estimated Effort

| Phase | Tasks | Estimated Effort |
|-------|-------|------------------|
| Phase 1: Setup | 4 | 1-2 hours |
| Phase 2: Foundational | 9 | 2-3 hours |
| Phase 3: US1 | 8 | 2-3 hours |
| Phase 4: US4 | 5 | 1 hour |
| Phase 5: US3 | 9 | 2-3 hours |
| Phase 6: US2 | 5 | 1 hour |
| Phase 7: Polish | 8 | 1-2 hours |
| **Total** | **48** | **10-15 hours** |

---

## Notes

- All file paths are relative to repository root
- Validation tasks (T020, T021, T026, T031, T043) are critical checkpoints
- Schema validation (T019) is the key to providing clear error messages per FR-008/FR-017/FR-018
- Personal data removal (T010, T011, T012) must happen before merge to main
- Example consumer flake (T028-T031) serves as living documentation
- Commit after each task or logical group; push after each phase checkpoint