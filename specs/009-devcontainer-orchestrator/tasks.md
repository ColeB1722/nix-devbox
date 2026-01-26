# Tasks: Multi-Platform Development Environment

**Input**: Design documents from `/specs/009-devcontainer-orchestrator/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, contracts/ ✅, quickstart.md ✅

**Tests**: Not requested - implementation tasks only.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

Based on plan.md project structure:
- NixOS modules: `nixos/`
- Darwin modules: `darwin/`
- Container definitions: `containers/`
- Home Manager: `home/modules/`, `home/profiles/`, `home/users/`
- CLI tool: `scripts/devbox-ctl/`
- Library: `lib/`
- Host configs: `hosts/`
- Examples: `examples/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization, flake updates, and schema definitions

- [x] T001 Update flake.nix to add nix-darwin input and darwinConfigurations output in flake.nix
- [x] T002 [P] Create container configuration schema with validation in lib/containers.nix
- [x] T003 [P] Extend lib/schema.nix to validate containers config block from users.nix
- [x] T004 [P] Create examples/users.nix with container configuration placeholder and conventions
- [x] T005 [P] Create containers/README.md documenting container build and usage

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T006 Create Home Manager remote-access module for code-server and zed-remote config in home/modules/remote-access.nix
- [x] T007 [P] Create Home Manager container profile importing cli, fish, git, dev, remote-access in home/profiles/container.nix
- [x] T008 [P] Create Home Manager workstation profile for local development (cli, fish, git, dev, no remote-access) in home/profiles/workstation.nix
- [x] T009 Create devbox-ctl Python CLI with click framework in scripts/devbox-ctl/devbox_ctl.py
- [x] T010 [P] (merged into T009) Validation functions included in devbox_ctl.py
- [x] T011 [P] (merged into T009) 1Password integration included in devbox_ctl.py
- [x] T012 Create devbox-ctl Nix package definition in scripts/devbox-ctl/package.nix

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 2 - Deploy Orchestrator Host (Priority: P1) 🎯 MVP

**Goal**: Administrator can deploy NixOS orchestrator on bare-metal or WSL2 with SSH access and Podman ready

**Independent Test**: `nixos-rebuild switch --flake .#devbox` completes, SSH works with key auth, `podman ps` succeeds

### Implementation for User Story 2

- [x] T013 [US2] Create orchestrator NixOS module enabling Podman, devbox-ctl, 1Password CLI, git, and gh in nixos/orchestrator.nix
- [x] T014 [P] [US2] Create orchestrator cleanup timer module for idle container management in nixos/orchestrator-cleanup.nix
- [x] T015 [US2] Update hosts/devbox/default.nix to import orchestrator module
- [x] T016 [P] [US2] Update hosts/devbox-wsl/default.nix to import orchestrator module (with WSL-specific adjustments)
- [x] T017 [US2] Update hosts/README.md documenting orchestrator deployment on both platforms

**Checkpoint**: Orchestrator deploys on bare-metal and WSL2, SSH and Podman operational

---

## Phase 4: User Story 1 - Spin Up a Dev Container (Priority: P1)

**Goal**: Developer can create an isolated dev container with Tailscale SSH, code-server, and Zed remote access

**Independent Test**: Run `devbox-ctl create test-container`, SSH via `ssh dev@test-container`, access code-server in browser

### Implementation for User Story 1

- [x] T018 [US1] Create base devcontainer image definition with CLI tools in containers/devcontainer/default.nix
- [x] T019 [P] [US1] Create Tailscale setup layer for container with userspace networking in containers/devcontainer/default.nix (integrated)
- [x] T020 [P] [US1] Create code-server layer for browser-based IDE in containers/devcontainer/default.nix (integrated)
- [x] T021 [P] [US1] Create Zed remote server layer in containers/devcontainer/default.nix (Zed uses SSH, no separate server needed)
- [x] T022 [US1] Create container entrypoint script with Tailscale init in containers/devcontainer/default.nix (embedded)
- [x] T023 [US1] Implement devbox-ctl create subcommand with validation, 1Password retrieval, Podman run in scripts/devbox-ctl/devbox_ctl.py
- [x] T024 [US1] Add container image build output to flake.nix packages

**Checkpoint**: Developers can create and access dev containers via Tailscale SSH, code-server, and Zed

---

## Phase 5: User Story 3 - Manage Container Lifecycle (Priority: P2)

**Goal**: Developer can stop, start, and destroy containers with state preservation

**Independent Test**: Create container, stop it, start it (state preserved), destroy it (Tailscale device removed)

### Implementation for User Story 3

- [x] T025 [US3] Implement devbox-ctl list subcommand with JSON output option in scripts/devbox-ctl/devbox_ctl.py
- [x] T026 [P] [US3] Implement devbox-ctl start subcommand with resource checking in scripts/devbox-ctl/devbox_ctl.py
- [x] T027 [P] [US3] Implement devbox-ctl stop subcommand with state preservation in scripts/devbox-ctl/devbox_ctl.py
- [x] T028 [US3] Implement devbox-ctl destroy subcommand with Tailscale cleanup and volume handling in scripts/devbox-ctl/devbox_ctl.py
- [x] T029 [P] [US3] Implement devbox-ctl status subcommand with resource usage display in scripts/devbox-ctl/devbox_ctl.py
- [x] T030 [P] [US3] Implement devbox-ctl logs subcommand with follow and tail options in scripts/devbox-ctl/devbox_ctl.py
- [x] T031 [US3] Create containers.json registry file management in scripts/devbox-ctl/devbox_ctl.py for tracking container state

**Checkpoint**: Full container lifecycle management operational (create, list, start, stop, destroy, status, logs)

---

## Phase 6: User Story 6 - Per-User Secrets and Tagging (Priority: P2)

**Goal**: Each user's containers have unique Tailscale tags and credentials from 1Password

**Independent Test**: Two users create containers, verify different Tailscale tags via `tailscale status`

### Implementation for User Story 6

- [x] T032 [US6] Implement 1Password reference format (op://{vault}/{username}-tailscale-authkey/password) in scripts/devbox-ctl/devbox_ctl.py
- [x] T033 [US6] Apply user-specific Tailscale tags (tag:devcontainer, tag:{username}-container) in scripts/devbox-ctl/devbox_ctl.py
- [x] T034 [US6] Validate username in scripts/devbox-ctl/devbox_ctl.py
- [ ] T035 [P] [US6] Document 1Password Service Account setup in quickstart.md consumer setup section
- [x] T036 [US6] Implement devbox-ctl rotate-key subcommand to update Tailscale auth key without recreating container in scripts/devbox-ctl/devbox_ctl.py

**Checkpoint**: Per-user isolation verified - containers have unique tags, users cannot access each other's containers

---

## Phase 7: User Story 4 - Use macOS Workstation (Priority: P2)

**Goal**: Developer on macOS has fully-configured local development environment with Aerospace tiling

**Independent Test**: Run `darwin-rebuild switch --flake .#macbook`, verify CLI tools, Aerospace hotkeys work

### Implementation for User Story 4

- [ ] T037 [US4] Create nix-darwin core module with base system configuration in darwin/core.nix
- [ ] T038 [P] [US4] Create Aerospace tiling window manager module with keybindings in darwin/aerospace.nix
- [ ] T039 [P] [US4] Create darwin CLI tools module importing home/modules/cli.nix via home-manager in darwin/cli.nix
- [ ] T040 [P] [US4] Create darwin GUI applications module (placeholder for future Obsidian, etc.) in darwin/apps.nix
- [ ] T041 [US4] Create darwin host configuration importing core, aerospace, cli, apps in hosts/macbook/default.nix
- [ ] T042 [US4] Update flake.nix with darwinConfigurations.macbook output

**Checkpoint**: macOS workstation deployment complete with full CLI tooling and Aerospace tiling

---

## Phase 8: User Story 5 - Use Headful NixOS Desktop (Priority: P3)

**Goal**: Developer on Linux has NixOS workstation with Hyprland tiling and full CLI tooling

**Independent Test**: Deploy to bare-metal, boot to Hyprland, verify CLI tools and tiling hotkeys

### Implementation for User Story 5

- [ ] T043 [US5] Create headful NixOS host configuration with Hyprland enabled in hosts/devbox-desktop/default.nix
- [ ] T044 [P] [US5] Create hardware-configuration.nix.example for headful desktop in hosts/devbox-desktop/hardware-configuration.nix.example
- [ ] T045 [US5] Update home/users/coal.nix to support headful profile when deployed on desktop
- [ ] T046 [US5] Document GPU requirements and Hyprland troubleshooting in hosts/README.md

**Checkpoint**: Headful NixOS desktop deploys with Hyprland and full CLI tooling

---

## Phase 9: User Story 7 - Sync Files Between Container and Local Workstation (Priority: P3)

**Goal**: Developer can optionally enable Syncthing in container for bidirectional file sync with local machine

**Independent Test**: Create container with `--with-syncthing`, pair local Syncthing, verify files sync bidirectionally

### Implementation for User Story 7

- [ ] T047 [US7] Create Syncthing layer for dev containers with ports bound to Tailscale interface only in containers/devcontainer/syncthing.nix
- [ ] T048 [US7] Update containers/devcontainer/default.nix to optionally include Syncthing layer
- [ ] T049 [US7] Update entrypoint.sh to start Syncthing daemon when --with-syncthing flag used in containers/devcontainer/entrypoint.sh
- [ ] T050 [US7] Update create.sh to support --with-syncthing flag and display Syncthing URLs in scripts/devbox-ctl/create.sh
- [ ] T051 [US7] Document Syncthing pairing workflow in quickstart.md

**Checkpoint**: Optional Syncthing file sync works between container and local workstation

---

## Phase 10: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [ ] T052 [P] Add NixOS assertions for orchestrator security (firewall enabled, SSH hardened) in nixos/orchestrator.nix
- [ ] T053 [P] Add error handling and user-friendly messages to all devbox-ctl subcommands
- [ ] T054 [P] Create man page or --help documentation for devbox-ctl in scripts/devbox-ctl/devbox-ctl
- [ ] T055 Run quickstart.md validation end-to-end for all 4 host configurations
- [ ] T056 [P] Update AGENTS.md with new module references and service access table
- [ ] T057 Code cleanup: ensure consistent Nix style, comments on non-obvious decisions

---

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1 (Setup) ──────────────────────────────────────────────────────────────►
         │
         ▼
Phase 2 (Foundational) ───────────────────────────────────────────────────────►
         │
         ├──► Phase 3 (US2: Orchestrator) ─────► Phase 4 (US1: Containers) ──►
         │                                              │
         │                                              ▼
         │                                       Phase 5 (US3: Lifecycle) ───►
         │                                              │
         │                                              ▼
         │                                       Phase 6 (US6: Secrets) ─────►
         │
         ├──► Phase 7 (US4: macOS) ──────────────────────────────────────────►
         │
         ├──► Phase 8 (US5: Headful NixOS) ──────────────────────────────────►
         │
         └──► Phase 9 (US7: Syncthing) ──────────────────────────────────────►
                                                        │
                                                        ▼
                                                 Phase 10 (Polish) ──────────►
```

### User Story Dependencies

- **User Story 2 (Orchestrator)**: Foundational complete → Can start immediately
- **User Story 1 (Containers)**: Depends on US2 (orchestrator must exist to run containers)
- **User Story 3 (Lifecycle)**: Depends on US1 (containers must be creatable to manage)
- **User Story 6 (Secrets/Tags)**: Depends on US3 (refines existing create/validation)
- **User Story 4 (macOS)**: Foundational complete → Can start in parallel with US2
- **User Story 5 (Headful NixOS)**: Foundational complete → Can start in parallel with US2
- **User Story 7 (Syncthing)**: Depends on US1 (adds optional layer to container creation)

### Within Each User Story

- Schema/library before modules
- Modules before CLI tools
- Container layers before entrypoint
- Core implementation before integration

### Parallel Opportunities

**Phase 1 (all [P] can run together):**
- T002, T003, T004, T005

**Phase 2 (after T009):**
- T007, T008 (after T006)
- T010, T011 (independent of T009)

**Phase 4 (after T018):**
- T019, T020, T021 (all container layers)

**Phase 5:**
- T026, T027, T029, T030 (different files)

**Phase 7:**
- T038, T039, T040 (different darwin modules)

**Cross-phase parallelism:**
- US4 (macOS), US5 (Headful NixOS) can proceed in parallel after Foundational
- US7 (Syncthing) can proceed in parallel with US3-US6 once US1 container base exists

---

## Parallel Example: Phase 4 (User Story 1)

```bash
# After T018 (base container) is complete, launch layers in parallel:
Task T019: "Create Tailscale setup layer in containers/devcontainer/tailscale.nix"
Task T020: "Create code-server layer in containers/devcontainer/code-server.nix"
Task T021: "Create Zed remote server layer in containers/devcontainer/zed-remote.nix"
```

---

## Parallel Example: Phase 7 (User Story 4)

```bash
# After T037 (darwin core) is complete, launch modules in parallel:
Task T038: "Create Aerospace tiling window manager module in darwin/aerospace.nix"
Task T039: "Create darwin CLI tools module in darwin/cli.nix"
Task T040: "Create darwin GUI applications module in darwin/apps.nix"
```

---

## Implementation Strategy

### MVP First (User Stories 1 + 2 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 2 (Orchestrator)
4. Complete Phase 4: User Story 1 (Dev Containers)
5. **STOP and VALIDATE**: Test container creation and access
6. Deploy/demo MVP

### Incremental Delivery

| Milestone | User Stories | What's Deliverable |
|-----------|--------------|-------------------|
| MVP | US1 + US2 | Orchestrator + basic container creation |
| Lifecycle | + US3 | Full container management |
| Security | + US6 | Per-user isolation |
| macOS | + US4 | Local macOS development |
| Linux Desktop | + US5 | Local NixOS development |
| File Sync | + US7 | Optional Syncthing support |

### Single Developer Strategy

1. Phase 1 → Phase 2 → Phase 3 → Phase 4 (MVP!)
2. Validate MVP works end-to-end
3. Phase 5 → Phase 6 (complete container management)
4. Phase 7 (macOS) OR Phase 8 (Linux) based on personal hardware
5. Phase 9 (Syncthing) if file sync needed
6. Phase 10 (Polish)

### Team Strategy (2+ developers)

After Foundational complete:
- Developer A: US2 → US1 → US3 → US6 (container track)
- Developer B: US4 → US5 → US7 (workstation track)
- Merge and integrate at Phase 10

---

## Summary

| Metric | Value |
|--------|-------|
| **Total Tasks** | 57 |
| **Setup Tasks** | 5 |
| **Foundational Tasks** | 7 |
| **User Story 1 Tasks** | 7 |
| **User Story 2 Tasks** | 5 |
| **User Story 3 Tasks** | 7 |
| **User Story 4 Tasks** | 6 |
| **User Story 5 Tasks** | 4 |
| **User Story 6 Tasks** | 5 |
| **User Story 7 Tasks** | 5 |
| **Polish Tasks** | 6 |
| **Parallelizable Tasks** | 29 (51%) |
| **MVP Scope** | US1 + US2 (19 tasks) |

**Format Validation**: ✅ All tasks follow checklist format (checkbox, ID, labels, file paths)