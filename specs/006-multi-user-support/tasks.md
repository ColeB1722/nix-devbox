# Tasks: Multi-User Support

**Input**: Design documents from `/specs/006-multi-user-support/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Not explicitly requested - no test tasks included.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4)
- Include exact file paths in descriptions

## Path Conventions

This is a NixOS configuration project:
- **Modules**: `modules/` - NixOS system modules
- **Home Manager**: `home/` - Per-user Home Manager configs
- **Hosts**: `hosts/` - Machine-specific configurations

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Prepare the codebase for multi-user refactoring

- [ ] T001 Create `home/common.nix` by extracting shared config from `home/default.nix`
- [ ] T002 [P] Add `.env.example` with SSH_KEY_COAL and SSH_KEY_VIOLINO placeholders at repo root
- [ ] T003 [P] Update `.gitignore` to exclude `.env` file at repo root

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T004 Refactor `modules/user/default.nix` to support multiple users with env var SSH key injection
- [ ] T005 Add placeholder key logic with `lib.warn` for missing SSH keys in `modules/user/default.nix`
- [ ] T006 Add optional strict mode assertions (NIX_STRICT_KEYS) in `modules/user/default.nix`
- [ ] T007 Verify `nix flake check` passes with empty SSH key env vars (placeholder keys used)

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1 - coal accesses Devbox as Primary Admin (Priority: P1) 🎯 MVP

**Goal**: coal can SSH into devbox with admin privileges, use all dev tools, and access code-server

**Independent Test**: SSH as coal, run `sudo whoami`, `docker ps`, access code-server at localhost:8080

### Implementation for User Story 1

- [ ] T008 [US1] Define coal's user account in `modules/user/default.nix` (uid=1000, wheel group, docker group)
- [ ] T009 [US1] Create `home/coal.nix` with coal's personal config (imports common.nix, git identity)
- [ ] T010 [US1] Wire coal's Home Manager config in `modules/user/default.nix` via `home-manager.users.coal`
- [ ] T011 [US1] Update `modules/services/code-server.nix` to run as user `coal` on port 8080
- [ ] T012 [US1] Verify coal's account works with `nix flake check` (with SSH_KEY_COAL set)
- [ ] T013 [US1] Document coal's setup in inline comments in `modules/user/default.nix`

**Checkpoint**: User Story 1 complete - coal has full admin access with dev tools

---

## Phase 4: User Story 2 - Violino Accesses Devbox as Secondary User (Priority: P2)

**Goal**: Violino can SSH into devbox with her own account, has isolated home directory

**Independent Test**: SSH as Violino, verify separate home directory, verify dev tools work

### Implementation for User Story 2

- [ ] T014 [US2] Define Violino's user account in `modules/user/default.nix` (uid=1001, docker group, NO wheel)
- [ ] T015 [US2] Create `home/violino.nix` with Violino's personal config (imports common.nix, git identity)
- [ ] T016 [US2] Wire Violino's Home Manager config in `modules/user/default.nix` via `home-manager.users.violino`
- [ ] T017 [US2] Verify Violino's account works with `nix flake check` (with SSH_KEY_VIOLINO set)
- [ ] T018 [US2] Document Violino's setup in inline comments in `modules/user/default.nix`

**Checkpoint**: User Story 2 complete - Violino has her own isolated account

---

## Phase 5: User Story 3 - User Isolation and Security (Priority: P2)

**Goal**: Both users have proper isolation via Unix permissions; shared resources (docker) work for both

**Independent Test**: Verify coal cannot read Violino's home; both can run `docker ps`

### Implementation for User Story 3

- [ ] T019 [US3] Configure home directory permissions (700) in `modules/user/default.nix`
- [ ] T020 [US3] Verify both users are in docker group in `modules/user/default.nix`
- [ ] T021 [US3] Verify only coal is in wheel group (sudo access) in `modules/user/default.nix`
- [ ] T022 [US3] Add assertion that Violino is NOT in wheel group in `modules/user/default.nix`
- [ ] T023 [US3] Run `nix flake check` to validate all assertions pass

**Checkpoint**: User Story 3 complete - Users are properly isolated with shared resource access

---

## Phase 6: User Story 4 - Per-User Home Manager Configuration (Priority: P3)

**Goal**: Each user has personalized environment (shell aliases, git config) without conflicts

**Independent Test**: Verify coal's git user.name differs from Violino's; each has own fish config

### Implementation for User Story 4

- [ ] T024 [US4] Configure coal's git identity (userName, userEmail) in `home/coal.nix`
- [ ] T025 [P] [US4] Configure Violino's git identity (userName, userEmail) in `home/violino.nix`
- [ ] T026 [US4] Add any coal-specific shell abbreviations in `home/coal.nix` (if different from common)
- [ ] T027 [P] [US4] Add any Violino-specific shell abbreviations in `home/violino.nix` (if different from common)
- [ ] T028 [US4] Verify `nix flake check` passes with both user configs

**Checkpoint**: User Story 4 complete - Each user has personalized environment

---

## Phase 7: Per-User code-server (Extension of US1/US2)

**Goal**: Each user has their own code-server instance on dedicated ports

**Independent Test**: coal accesses code-server on 8080; Violino on 8081

### Implementation

- [ ] T029 Refactor `modules/services/code-server.nix` to support multiple instances
- [ ] T030 [P] Configure coal's code-server instance (port 8080) in `modules/services/code-server.nix`
- [ ] T031 [P] Configure Violino's code-server instance (port 8081) in `modules/services/code-server.nix`
- [ ] T032 Maintain Tailscale assertion for code-server access in `modules/services/code-server.nix`
- [ ] T033 Verify both code-server services with `nix flake check`

---

## Phase 8: Host Configuration Updates

**Goal**: Ensure both devbox and devbox-wsl configurations work with multi-user setup

### Implementation

- [ ] T034 Verify `hosts/devbox/default.nix` imports work with refactored user module
- [ ] T035 [P] Verify `hosts/devbox-wsl/default.nix` imports work with refactored user module
- [ ] T036 Run `nix flake check` for both configurations
- [ ] T037 Update `AGENTS.md` with new file structure (home/common.nix, home/coal.nix, home/violino.nix)

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, cleanup, and final validation

- [ ] T038 [P] Add inline documentation to `modules/user/default.nix` explaining multi-user pattern
- [ ] T039 [P] Add inline documentation to `home/common.nix` explaining shared config pattern
- [ ] T040 [P] Remove old single-user code from `home/default.nix` (replace with imports)
- [ ] T041 Update `specs/006-multi-user-support/quickstart.md` with actual env var names and verification steps
- [ ] T042 Run full `nix flake check` with both SSH keys set
- [ ] T043 Run full `nix flake check` without SSH keys (verify placeholder warning, build succeeds)
- [ ] T044 Verify pre-commit hooks pass (nixfmt, statix, deadnix)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup - BLOCKS all user stories
- **User Stories (Phases 3-6)**: All depend on Foundational phase completion
- **code-server (Phase 7)**: Depends on US1 and US2 user accounts existing
- **Host Config (Phase 8)**: Depends on all module changes being complete
- **Polish (Phase 9)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational - No dependencies on other stories
- **User Story 2 (P2)**: Can start after Foundational - Independent of US1
- **User Story 3 (P2)**: Depends on both US1 and US2 (needs both users to test isolation)
- **User Story 4 (P3)**: Depends on US1 and US2 (needs both user configs to exist)

### Within Each User Story

- Define user account before Home Manager config
- Wire Home Manager after creating per-user .nix file
- Verify with `nix flake check` after each major change

### Parallel Opportunities

- T002 and T003 (Setup phase)
- T024 and T025, T026 and T027 (US4 - different user files)
- T030 and T031 (code-server - same file but different sections, may need sequential)
- T034 and T035 (different host files)
- T038, T039, T040 (different files)

---

## Parallel Example: User Story 4

```bash
# These tasks modify different files and can run in parallel:
Task: "Configure coal's git identity in home/coal.nix"
Task: "Configure Violino's git identity in home/violino.nix"

# These also can run in parallel:
Task: "Add coal-specific shell abbreviations in home/coal.nix"
Task: "Add Violino-specific shell abbreviations in home/violino.nix"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: coal can SSH, sudo, docker, code-server
5. Deploy/demo if ready

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → coal works → MVP!
3. Add User Story 2 → Violino works
4. Add User Story 3 → Isolation verified
5. Add User Story 4 → Per-user configs
6. Add code-server multi-instance → Full feature complete

### Single Developer Strategy

Execute phases sequentially in priority order:
1. Setup → Foundational → US1 (MVP)
2. US2 → US3 → US4
3. code-server → Host configs → Polish

---

## Summary

| Phase | Tasks | Parallel Opportunities |
|-------|-------|------------------------|
| Setup | 3 | 2 tasks parallelizable |
| Foundational | 4 | Sequential (same file) |
| US1 (P1) | 6 | Mostly sequential |
| US2 (P2) | 5 | Mostly sequential |
| US3 (P2) | 5 | Sequential (same file) |
| US4 (P3) | 5 | 4 tasks parallelizable |
| code-server | 5 | 2 tasks parallelizable |
| Host Config | 4 | 2 tasks parallelizable |
| Polish | 7 | 3 tasks parallelizable |

**Total Tasks**: 44
**MVP Tasks (through US1)**: 13

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Verify `nix flake check` passes after each phase
- Commit after each task or logical group
- Use SSH_KEY_COAL and SSH_KEY_VIOLINO env vars for testing
