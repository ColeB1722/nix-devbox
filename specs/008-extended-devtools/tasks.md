# Tasks: Extended Development Tools

**Input**: Design documents from `/specs/008-extended-devtools/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, quickstart.md ✅

**Tests**: Not explicitly requested - implementation validation via `nix flake check` and manual acceptance testing per spec.md criteria.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Home Manager modules**: `home/modules/`
- **NixOS modules**: `nixos/`
- **Darwin modules**: `darwin/`
- **Host configurations**: `hosts/devbox/`, `hosts/devbox-wsl/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Verify project state and prepare for implementation

- [x] T001 Verify flake builds successfully with `nix flake check`
- [x] T002 [P] Review existing home/modules/dev.nix structure for package additions
- [x] T003 [P] Review existing home/modules/cli.nix structure for package additions
- [x] T004 [P] Review hosts/devbox/default.nix for module import patterns

**Checkpoint**: Existing configuration verified, ready for module additions

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core module structure that enables user story implementation

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T005 Create nixos/podman.nix module skeleton with devbox.podman options in nixos/podman.nix
- [x] T006 [P] Create nixos/ttyd.nix module skeleton with devbox.ttyd options in nixos/ttyd.nix
- [x] T007 [P] Create nixos/syncthing.nix module skeleton with devbox.syncthing options in nixos/syncthing.nix
- [x] T008 [P] Create nixos/hyprland.nix module skeleton with devbox.hyprland options in nixos/hyprland.nix
- [x] T009 Run `nix flake check` to verify module skeletons parse correctly

**Checkpoint**: Foundation ready - all module files exist with valid Nix syntax

---

## Phase 3: User Story 1 - Core CLI Tools Installation (Priority: P1) 🎯 MVP

**Goal**: Add goose, cargo, yazi to user environment for enhanced development workflow

**Independent Test**: After rebuild, run `goose --help`, `cargo --version`, and `yazi --version` successfully

### Implementation for User Story 1

- [x] T010 [P] [US1] Add yazi package to home/modules/cli.nix in File Navigation section
- [x] T011 [P] [US1] Add goose-cli package to home/modules/dev.nix in AI Coding Tools section
- [x] T012 [P] [US1] Add Rust toolchain section to home/modules/dev.nix with rustc, cargo, rustfmt, clippy
- [x] T013 [US1] Run `nix flake check` to verify Home Manager module changes
- [x] T014 [US1] Build configuration with `nixos-rebuild build --flake .#devbox-wsl` to verify packages resolve
- [x] T015 [US1] Update home/modules/dev.nix header comment to document new Rust Toolchain section

**Checkpoint**: User Story 1 complete - CLI tools available after rebuild

---

## Phase 4: User Story 2 - Container Runtime with Podman (Priority: P2)

**Goal**: Rootless Podman container runtime for bare-metal NixOS (not WSL)

**Independent Test**: On bare-metal host, run `podman run hello-world` successfully

### Implementation for User Story 2

- [x] T016 [US2] Implement devbox.podman.enable option with mkEnableOption in nixos/podman.nix
- [x] T017 [US2] Implement devbox.podman.dockerCompat option (default: true) in nixos/podman.nix
- [x] T018 [US2] Implement devbox.podman.enableDns option (default: true) in nixos/podman.nix
- [x] T019 [US2] Implement virtualisation.containers.enable and virtualisation.podman config in nixos/podman.nix
- [x] T020 [US2] Implement subUidRanges/subGidRanges for all users via lib.genAttrs in nixos/podman.nix
- [x] T021 [US2] Add assertion to prevent Podman + Docker conflict in nixos/podman.nix
- [x] T022 [US2] Add nixos/podman.nix import to hosts/devbox/default.nix (bare-metal only)
- [x] T023 [US2] Verify hosts/devbox-wsl/default.nix does NOT import podman module (uses Docker Desktop)
- [x] T024 [US2] Run `nix flake check` to verify Podman module
- [x] T025 [US2] Add constitution alignment comment header to nixos/podman.nix

**Checkpoint**: User Story 2 complete - Podman available on bare-metal NixOS

---

## Phase 5: User Story 3 - Terminal Sharing with ttyd (Priority: P3)

**Goal**: Web-based terminal sharing accessible only via Tailscale network

**Independent Test**: Run `ttyd fish`, access via Tailscale IP in browser

### Implementation for User Story 3

- [x] T026 [US3] Implement devbox.ttyd.enable option with mkEnableOption in nixos/ttyd.nix
- [x] T027 [US3] Implement devbox.ttyd.port option (default: 7681) in nixos/ttyd.nix
- [x] T028 [US3] Implement devbox.ttyd.shell option (default: "fish") in nixos/ttyd.nix
- [x] T029 [US3] Add ttyd to environment.systemPackages when enabled in nixos/ttyd.nix
- [x] T030 [US3] Configure firewall to allow ttyd port only on tailscale0 interface in nixos/ttyd.nix
- [x] T031 [US3] Add nixos/ttyd.nix import to hosts/devbox/default.nix
- [x] T032 [US3] Add nixos/ttyd.nix import to hosts/devbox-wsl/default.nix
- [x] T033 [US3] Run `nix flake check` to verify ttyd module
- [x] T034 [US3] Add constitution alignment comment header to nixos/ttyd.nix

**Checkpoint**: User Story 3 complete - ttyd available with Tailscale-only access

---

## Phase 6: User Story 4 - File Synchronization with Syncthing (Priority: P3)

**Goal**: Syncthing service running with web UI accessible via Tailscale

**Independent Test**: Access Syncthing web UI at http://hostname:8384 via Tailscale

### Implementation for User Story 4

- [x] T035 [US4] Implement devbox.syncthing.enable option with mkEnableOption in nixos/syncthing.nix
- [x] T036 [US4] Implement devbox.syncthing.user option (default: first admin) in nixos/syncthing.nix
- [x] T037 [US4] Implement devbox.syncthing.dataDir option in nixos/syncthing.nix
- [x] T038 [US4] Implement devbox.syncthing.guiPort option (default: 8384) in nixos/syncthing.nix
- [x] T039 [US4] Configure services.syncthing with user, group, dataDir, configDir in nixos/syncthing.nix
- [x] T040 [US4] Configure firewall for GUI port (8384) on tailscale0 interface in nixos/syncthing.nix
- [x] T041 [US4] Configure firewall for sync ports (22000 TCP/UDP, 21027 UDP) on tailscale0 in nixos/syncthing.nix
- [x] T042 [US4] Add assertion to verify syncthing user exists in nixos/syncthing.nix
- [x] T043 [US4] Add nixos/syncthing.nix import to hosts/devbox/default.nix
- [x] T044 [US4] Add nixos/syncthing.nix import to hosts/devbox-wsl/default.nix
- [x] T045 [US4] Run `nix flake check` to verify Syncthing module
- [x] T046 [US4] Add constitution alignment comment header to nixos/syncthing.nix

**Checkpoint**: User Story 4 complete - Syncthing service configured with Tailscale-only access

---

## Phase 7: User Story 5 - macOS Window Management with Aerospace (Priority: P3) 🚧 DEFERRED

**Goal**: Aerospace tiling window manager for nix-darwin

**Independent Test**: After darwin-rebuild, Aerospace responds to keybindings

**Status**: DEFERRED - nix-darwin support not yet implemented (see darwin/README.md)

### Implementation for User Story 5 (Future)

- [ ] T047 [US5] Create darwin/aerospace.nix module skeleton when nix-darwin is implemented
- [ ] T048 [US5] Implement devbox.aerospace.enable option in darwin/aerospace.nix
- [ ] T049 [US5] Implement devbox.aerospace.startAtLogin option in darwin/aerospace.nix
- [ ] T050 [US5] Add aerospace package to home.packages in darwin/aerospace.nix
- [ ] T051 [US5] Add xdg.configFile for aerospace.toml configuration in darwin/aerospace.nix

**Checkpoint**: User Story 5 deferred until nix-darwin implementation

---

## Phase 8: User Story 6 - Linux Desktop with Hyprland (Priority: P4)

**Goal**: Opt-in Hyprland compositor for headed NixOS (not WSL, not headless)

**Independent Test**: On headed NixOS, boot into Hyprland session

### Implementation for User Story 6

- [x] T052 [US6] Implement devbox.hyprland.enable option with mkEnableOption in nixos/hyprland.nix
- [x] T053 [US6] Implement devbox.hyprland.xwayland option (default: true) in nixos/hyprland.nix
- [x] T054 [US6] Configure programs.hyprland.enable when devbox.hyprland.enable is true in nixos/hyprland.nix
- [x] T055 [US6] Configure programs.hyprland.xwayland.enable in nixos/hyprland.nix
- [x] T056 [US6] Add services.xserver.enable and services.displayManager.sddm.enable in nixos/hyprland.nix
- [x] T057 [US6] Add warning when Hyprland enabled on WSL config in nixos/hyprland.nix
- [x] T058 [US6] Add nixos/hyprland.nix import to hosts/devbox/default.nix (opt-in, disabled by default)
- [x] T059 [US6] Verify hosts/devbox-wsl/default.nix does NOT enable Hyprland
- [x] T060 [US6] Run `nix flake check` to verify Hyprland module
- [x] T061 [US6] Add constitution alignment comment header with Principle II violation note to nixos/hyprland.nix

**Checkpoint**: User Story 6 complete - Hyprland available as opt-in for headed systems

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, validation, and cleanup

- [x] T062 [P] Update AGENTS.md if not already updated by plan workflow
- [x] T063 [P] Update docs/ with any new tool documentation if needed
- [x] T064 Run full `nix flake check` to verify all modules
- [x] T065 Run `just lint` to verify code style
- [x] T066 Run `just fmt` to format all Nix files
- [x] T067 Verify quickstart.md scenarios match implementation
- [x] T068 Create git commit with all changes for feature 008-extended-devtools

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup - creates module skeletons
- **User Stories (Phase 3-8)**: All depend on Foundational phase completion
  - US1 (P1): CLI tools - can start immediately after Phase 2
  - US2 (P2): Podman - can start immediately after Phase 2
  - US3 (P3): ttyd - can start immediately after Phase 2
  - US4 (P3): Syncthing - can start immediately after Phase 2
  - US5 (P3): Aerospace - DEFERRED until nix-darwin support
  - US6 (P4): Hyprland - can start immediately after Phase 2
- **Polish (Phase 9)**: Depends on all implemented user stories complete

### User Story Dependencies

- **User Story 1 (P1)**: No dependencies on other stories - Home Manager only
- **User Story 2 (P2)**: No dependencies on other stories - bare-metal only
- **User Story 3 (P3)**: Depends on Tailscale being enabled (existing)
- **User Story 4 (P3)**: Depends on Tailscale being enabled (existing)
- **User Story 5 (P3)**: Depends on nix-darwin support (NOT YET IMPLEMENTED)
- **User Story 6 (P4)**: No dependencies - opt-in module

### Within Each User Story

- Module options first
- Module config implementation second
- Host configuration imports third
- Validation (`nix flake check`) last

### Parallel Opportunities

Within Phase 2 (Foundational):
- T005, T006, T007, T008 can all run in parallel (different files)

Within Phase 3 (US1):
- T010, T011, T012 can all run in parallel (different sections of different files)

Across User Stories:
- US1, US2, US3, US4, US6 can all be implemented in parallel after Phase 2

---

## Parallel Example: Phase 2 (Foundational)

```text
# Launch all module skeleton tasks together:
Task T005: "Create nixos/podman.nix module skeleton"
Task T006: "Create nixos/ttyd.nix module skeleton"
Task T007: "Create nixos/syncthing.nix module skeleton"
Task T008: "Create nixos/hyprland.nix module skeleton"
```

## Parallel Example: User Story 1 (CLI Tools)

```text
# Launch all package addition tasks together:
Task T010: "Add yazi package to home/modules/cli.nix"
Task T011: "Add goose-cli package to home/modules/dev.nix"
Task T012: "Add Rust toolchain section to home/modules/dev.nix"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T004)
2. Complete Phase 2: Foundational (T005-T009)
3. Complete Phase 3: User Story 1 (T010-T015)
4. **STOP and VALIDATE**: Test `goose --help`, `cargo --version`, `yazi --version`
5. Commit as working MVP

### Incremental Delivery

1. MVP (US1) → CLI tools available
2. Add US2 (Podman) → Container runtime available on bare-metal
3. Add US3 (ttyd) → Terminal sharing available
4. Add US4 (Syncthing) → File sync available
5. Skip US5 (Aerospace) → Deferred until nix-darwin
6. Add US6 (Hyprland) → Desktop option for headed systems (opt-in)

### Platform Considerations

| User Story | devbox (bare-metal) | devbox-wsl |
|------------|---------------------|------------|
| US1 (CLI tools) | ✅ | ✅ |
| US2 (Podman) | ✅ | ❌ (uses Docker Desktop) |
| US3 (ttyd) | ✅ | ✅ |
| US4 (Syncthing) | ✅ | ✅ |
| US5 (Aerospace) | ❌ (not macOS) | ❌ (not macOS) |
| US6 (Hyprland) | ✅ (opt-in) | ❌ (no display) |

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Constitution compliance verified in each module header comment
- Aerospace (US5) is deferred - do not block on it
- Hyprland (US6) is opt-in by default due to headless-first principle
- WSL uses Docker Desktop - do NOT import Podman module on devbox-wsl

## Constitution Violation Justification

**Principle II (Headless-First Design)** is violated by Aerospace (US5) and Hyprland (US6).

This violation is **justified and mitigated** per plan.md Complexity Tracking:
- Both are **lowest priority** (P3-P4)
- Both are **platform-specific** (only installed where applicable)
- Both are **opt-in** (disabled by default)
- Both are **isolated modules** (don't affect headless configurations)

The constitution's headless-first principle applies to the *default* configuration. Platform-specific opt-in modules for future expansion are acceptable when properly isolated.