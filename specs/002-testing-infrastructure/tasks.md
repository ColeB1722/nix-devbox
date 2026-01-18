# Tasks: Testing Infrastructure

**Input**: Design documents from `/specs/002-testing-infrastructure/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)

---

## Phase 1: Setup (Flake Infrastructure)

**Purpose**: Add git-hooks.nix and systems inputs, create forEachSystem helper

- [ ] T001 [US1] Add git-hooks.nix input to flake.nix
- [ ] T002 [US1] Add systems input to flake.nix
- [ ] T003 [US1] Create forEachSystem helper pattern in flake.nix

---

## Phase 2: User Story 1 - Pre-commit Code Quality Checks (Priority: P1)

**Goal**: Enable pre-commit hooks (nixfmt, statix, deadnix) that run automatically on commit

**Independent Test**: Run `nix develop` and verify hooks install, then commit a malformed .nix file

### Implementation for User Story 1

- [ ] T004 [US1] Add checks.${system}.pre-commit-check output to flake.nix
- [ ] T005 [US1] Add devShells.${system}.default output with shellHook to flake.nix
- [ ] T006 [US1] Add formatter.${system} output (nixfmt-rfc-style) to flake.nix

**Checkpoint**: Pre-commit hooks should work after `nix develop`

---

## Phase 3: User Story 2 - Local Flake Validation (Priority: P2)

**Goal**: Enable `nix flake check` to run all checks locally

**Independent Test**: Run `nix flake check` and verify it succeeds

### Implementation for User Story 2

- [ ] T007 [US2] Verify `nix flake check` runs pre-commit-check (automatic from checks output)
- [ ] T008 [US2] Test on macOS (aarch64-darwin) to verify cross-platform support

**Checkpoint**: `nix flake check` should pass on all supported systems

---

## Phase 4: User Story 3 - CI Build Verification (Priority: P3)

**Goal**: GitHub Actions workflow runs checks on every push/PR

**Independent Test**: Push a branch and verify CI runs

### Implementation for User Story 3

- [ ] T009 [P] [US3] Create .github/workflows/ci.yml with Nix installation
- [ ] T010 [US3] Add `nix flake check` step to CI workflow
- [ ] T011 [US3] Add NixOS configuration build step to CI workflow

**Checkpoint**: CI should run on push and report success/failure

---

## Phase 5: Polish & Validation

**Purpose**: Final validation and documentation

- [ ] T012 Run `nix flake check` to validate complete implementation
- [ ] T013 Test `nix develop` and verify hooks install correctly
- [ ] T014 Validate quickstart.md instructions work as documented

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies - start immediately
- **Phase 2 (US1)**: Depends on Phase 1 completion
- **Phase 3 (US2)**: Can run after Phase 2 (validation only)
- **Phase 4 (US3)**: Can run in parallel with Phase 2 (separate file)
- **Phase 5 (Polish)**: Depends on all phases complete

### Parallel Opportunities

- T009 (CI workflow) can run in parallel with T004-T006 (flake changes)
- T007 and T008 are validation tasks after implementation
