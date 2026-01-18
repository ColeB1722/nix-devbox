# Tasks: Development Tools and Configuration

**Input**: Design documents from `/specs/005-devtools-config/`  
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: No test tasks included (not requested in specification).

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2)
- Exact file paths included in all descriptions

## Path Conventions (NixOS Configuration)

```
flake.nix                    # Flake entry
modules/                     # NixOS system modules
├── shell/default.nix        # Fish shell (NEW)
├── docker/default.nix       # Docker daemon (NEW)
├── services/code-server.nix # code-server service (NEW)
└── user/default.nix         # User configuration (MODIFY)
home/default.nix             # Home Manager user config (EXTEND)
hosts/devbox/default.nix     # Bare-metal host (MODIFY)
hosts/devbox-wsl/default.nix # WSL host (MODIFY)
```

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Configure unfree packages and prepare for new modules

- [x] T001 Configure allowUnfreePredicate in flake.nix for claude-code, terraform, 1password-cli
- [x] T002 [P] Create modules/shell/ directory structure
- [x] T003 [P] Create modules/docker/ directory structure
- [x] T004 [P] Create modules/services/ directory structure

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core module structure that MUST be complete before user story implementation

**CRITICAL**: No user story work can begin until this phase is complete

- [x] T005 Create modules/shell/default.nix with constitution-aligned header comment and programs.fish.enable
- [x] T006 Update modules/user/default.nix to add docker group to user extraGroups
- [x] T007 Update modules/user/default.nix to set user shell to pkgs.fish
- [x] T008 Update hosts/devbox/default.nix to import new shell module (../../modules/shell)
- [x] T009 Update hosts/devbox-wsl/default.nix to import new shell module (../../modules/shell)
- [x] T010 Verify configuration builds with `nix flake check`

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1 - Shell Environment Ready on Login (Priority: P1) MVP

**Goal**: Fish shell with modern CLI tools (tree, ripgrep, fzf, bat, fd, eza) available on SSH login

**Independent Test**: SSH into devbox, verify fish is active, run `rg --version`, `fzf --version`, `bat --version`, `eza --version`

**Requirements**: FR-001, FR-002, FR-003, FR-004, FR-005, FR-006

### Implementation for User Story 1

- [x] T011 [US1] Add programs.fish configuration block to home/default.nix with shellAbbrs for git, nix, docker commands
- [x] T012 [US1] Add programs.fish.shellAliases to home/default.nix (ls=eza, ll, la, lt, cat=bat)
- [x] T013 [US1] Add programs.fish.interactiveShellInit to home/default.nix to disable greeting
- [x] T014 [P] [US1] Add programs.fzf configuration to home/default.nix with enableFishIntegration=true
- [x] T015 [P] [US1] Configure fzf defaultCommand, fileWidgetCommand, changeDirWidgetCommand using fd in home/default.nix
- [x] T016 [P] [US1] Add programs.bat configuration to home/default.nix with theme and pager settings
- [x] T017 [P] [US1] Add programs.eza configuration to home/default.nix with enableFishIntegration, icons, git
- [x] T018 [US1] Remove duplicate packages from home.packages (tree, ripgrep, fd already present) and add bat, eza, fzf
- [x] T019 [US1] Update programs.direnv in home/default.nix to add enableFishIntegration=true
- [x] T020 [US1] Build and verify: `nixos-rebuild build --flake .#devbox`

**Checkpoint**: User Story 1 complete - fish shell with CLI tools functional

---

## Phase 4: User Story 2 - Container Development Workflow (Priority: P1)

**Goal**: Docker daemon running, user can run containers without sudo

**Independent Test**: Run `docker run hello-world` without sudo, run `docker compose version`

**Requirements**: FR-007, FR-008, FR-009

### Implementation for User Story 2

- [x] T021 [US2] Create modules/docker/default.nix with constitution-aligned header comment
- [x] T022 [US2] Add virtualisation.docker configuration to modules/docker/default.nix (enable, enableOnBoot, autoPrune)
- [x] T023 [US2] Add WSL conditional in modules/docker/default.nix: lib.mkIf (!config.wsl.enable or false)
- [x] T024 [US2] Add assertion in modules/docker/default.nix to verify user is in docker group
- [x] T025 [US2] Update hosts/devbox/default.nix to import modules/docker
- [x] T026 [US2] Verify WSL host does NOT import docker module in hosts/devbox-wsl/default.nix (document exclusion)
- [x] T027 [US2] Build and verify: `nixos-rebuild build --flake .#devbox`

**Checkpoint**: User Stories 1 AND 2 complete - shell environment and Docker functional

---

## Phase 5: User Story 3 - AI-Assisted Coding Tools (Priority: P2)

**Goal**: OpenCode and Claude Code CLI tools installed and accessible

**Independent Test**: Run `opencode --version` and `claude --version`

**Requirements**: FR-010, FR-011, FR-012

### Implementation for User Story 3

- [x] T028 [P] [US3] Add opencode to home.packages in home/default.nix
- [x] T029 [P] [US3] Add claude-code to home.packages in home/default.nix
- [x] T030 [US3] Verify unfree packages build correctly: `nix flake check`

**Checkpoint**: User Story 3 complete - AI tools available

---

## Phase 6: User Story 4 - Remote IDE Access (Priority: P2)

**Goal**: code-server running on localhost:8080, Zed remote server available

**Independent Test**: Access http://localhost:8080 (via Tailscale), verify Zed client can connect

**Requirements**: FR-013, FR-014, FR-015

### Implementation for User Story 4

- [x] T031 [US4] Create modules/services/code-server.nix with constitution-aligned header comment
- [x] T032 [US4] Add services.code-server configuration to modules/services/code-server.nix (enable, host, port, auth, user)
- [x] T033 [US4] Add extraPackages to code-server config (git, nixfmt-rfc-style, nil, statix, deadnix)
- [x] T034 [US4] Add assertion in modules/services/code-server.nix to require Tailscale enabled
- [x] T035 [US4] Update hosts/devbox/default.nix to import modules/services/code-server.nix
- [x] T036 [P] [US4] Add home.file.".zed_server" configuration to home/default.nix for Zed remote server
- [x] T037 [US4] Build and verify: `nixos-rebuild build --flake .#devbox`

**Checkpoint**: User Story 4 complete - remote IDE access functional

---

## Phase 7: User Story 5 - Terminal Multiplexer (Priority: P2)

**Goal**: zellij available for persistent terminal sessions

**Independent Test**: Run `zellij`, create panes, detach and reattach

**Requirements**: FR-016, FR-017

### Implementation for User Story 5

- [x] T038 [US5] Add programs.zellij configuration to home/default.nix (enable, settings with default_shell=fish)
- [x] T039 [US5] Build and verify: `nixos-rebuild build --flake .#devbox`

**Checkpoint**: User Story 5 complete - terminal multiplexer functional

---

## Phase 8: User Story 6 - Version Control and Git Workflow (Priority: P2)

**Goal**: lazygit and gh CLI available for Git/GitHub workflows

**Independent Test**: Run `lazygit` in a git repo, run `gh auth status`

**Requirements**: FR-018, FR-019

### Implementation for User Story 6

- [x] T040 [P] [US6] Add programs.lazygit configuration to home/default.nix (enable, settings)
- [x] T041 [P] [US6] Add gh to home.packages in home/default.nix
- [x] T042 [US6] Build and verify: `nixos-rebuild build --flake .#devbox`

**Checkpoint**: User Story 6 complete - Git workflow tools functional

---

## Phase 9: User Story 7 - Package Management Tools (Priority: P2)

**Goal**: npm and uv available for JavaScript and Python package management

**Independent Test**: Run `npm --version` and `uv --version`

**Requirements**: FR-020, FR-021

### Implementation for User Story 7

- [x] T043 [P] [US7] Add nodejs to home.packages in home/default.nix (includes npm)
- [x] T044 [P] [US7] Add uv to home.packages in home/default.nix
- [x] T045 [US7] Build and verify: `nixos-rebuild build --flake .#devbox`

**Checkpoint**: User Story 7 complete - package managers functional

---

## Phase 10: User Story 8 - Infrastructure as Code (Priority: P3)

**Goal**: Terraform installed for infrastructure management

**Independent Test**: Run `terraform version`

**Requirements**: FR-022

### Implementation for User Story 8

- [x] T046 [US8] Add terraform to home.packages in home/default.nix
- [x] T047 [US8] Build and verify: `nixos-rebuild build --flake .#devbox`

**Checkpoint**: User Story 8 complete - Terraform functional

---

## Phase 11: User Story 9 - Secrets Management (Priority: P3)

**Goal**: 1Password CLI available for secure secret access

**Independent Test**: Run `op --version`

**Requirements**: FR-023

### Implementation for User Story 9

- [x] T048 [US9] Add programs._1password.enable = true to modules/user/default.nix (system-level)
- [x] T049 [US9] Add _1password-cli to home.packages in home/default.nix
- [x] T050 [US9] Build and verify: `nixos-rebuild build --flake .#devbox`

**Checkpoint**: User Story 9 complete - 1Password CLI functional

---

## Phase 12: User Story 10 - Code Review Integration (Priority: P3)

**Goal**: CodeRabbit documentation available for repository integration

**Independent Test**: Verify documentation is present and actionable

**Requirements**: FR-024

### Implementation for User Story 10

- [x] T051 [US10] Document CodeRabbit setup in specs/005-devtools-config/quickstart.md (already present)
- [x] T052 [US10] Verify quickstart.md CodeRabbit section is complete and accurate

**Checkpoint**: User Story 10 complete - CodeRabbit documentation available

---

## Phase 13: Polish & Cross-Cutting Concerns

**Purpose**: Final verification, documentation updates, and cleanup

- [x] T053 Run full `nix flake check` to verify all configurations pass
- [x] T054 [P] Update AGENTS.md with new technologies from this feature
- [x] T055 [P] Review and update specs/005-devtools-config/quickstart.md with any implementation changes
- [x] T056 Clean up any deprecated bash configuration from home/default.nix (keep for fallback or remove)
- [ ] T057 Verify shell startup time is under 500ms target (SC-006); if exceeded, lazy-load fzf bindings in home/default.nix
- [ ] T058 Run quickstart.md verification checklist on deployed system

---

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1: Setup ─────────────┐
                            ▼
Phase 2: Foundational ──────┤ (BLOCKS all user stories)
                            │
         ┌──────────────────┴──────────────────┐
         ▼                                     ▼
Phase 3: US1 Shell (P1)              Phase 4: US2 Docker (P1)
         │                                     │
         └──────────────────┬──────────────────┘
                            │
    ┌───────────┬───────────┼───────────┬───────────┐
    ▼           ▼           ▼           ▼           ▼
 Phase 5:   Phase 6:    Phase 7:    Phase 8:    Phase 9:
 US3 AI     US4 IDE     US5 zellij  US6 Git     US7 npm/uv
 (P2)       (P2)        (P2)        (P2)        (P2)
    │           │           │           │           │
    └───────────┴───────────┴───────────┴───────────┘
                            │
              ┌─────────────┼─────────────┐
              ▼             ▼             ▼
         Phase 10:     Phase 11:     Phase 12:
         US8 Terraform US9 1Password US10 CodeRabbit
         (P3)          (P3)          (P3)
              │             │             │
              └─────────────┴─────────────┘
                            │
                            ▼
                     Phase 13: Polish
```

### User Story Dependencies

| Story | Priority | Depends On | Can Parallelize With |
|-------|----------|------------|---------------------|
| US1 - Shell | P1 | Foundational | US2 |
| US2 - Docker | P1 | Foundational | US1 |
| US3 - AI Tools | P2 | US1 (shell) | US4, US5, US6 |
| US4 - Remote IDE | P2 | US1 (shell) | US3, US5, US6 |
| US5 - zellij | P2 | US1 (shell) | US3, US4, US6 |
| US6 - Git | P2 | US1 (shell) | US3, US4, US5 |
| US7 - npm/uv | P2 | US1 (shell) | US8, US9 |
| US8 - Terraform | P3 | US1 (shell) | US7, US9 |
| US9 - 1Password | P3 | US1 (shell) | US7, US8 |
| US10 - CodeRabbit | P3 | US6 (gh) | None |

### Parallel Opportunities

**Within Setup (Phase 1)**:
```bash
# All directory creation in parallel:
Task: T002 "Create modules/shell/ directory"
Task: T003 "Create modules/docker/ directory"
Task: T004 "Create modules/services/ directory"
```

**Within User Story 1 (Phase 3)**:
```bash
# All program configurations in parallel:
Task: T014 "programs.fzf configuration"
Task: T015 "fzf command configuration"
Task: T016 "programs.bat configuration"
Task: T017 "programs.eza configuration"
```

**Across User Stories (After Foundational)**:
```bash
# P1 stories in parallel:
Task: All US1 tasks
Task: All US2 tasks

# P2 stories in parallel (after US1):
Task: All US3 tasks
Task: All US4 tasks
Task: All US5 tasks
Task: All US6 tasks
```

---

## Implementation Strategy

### MVP First (User Story 1 + 2 Only)

1. Complete Phase 1: Setup (unfree config, directories)
2. Complete Phase 2: Foundational (shell module, user config)
3. Complete Phase 3: User Story 1 (fish + CLI tools)
4. Complete Phase 4: User Story 2 (Docker)
5. **STOP and VALIDATE**: Build, deploy, test shell and Docker work
6. Deploy/demo if ready - this is the MVP!

### Incremental Delivery

1. **MVP**: Setup + Foundational + US1 + US2 → Shell + Docker working
2. **+P2 Core**: Add US3-US7 → AI tools, IDE, zellij, git, packages
3. **+P3 Tools**: Add US8-US10 → Terraform, 1Password, CodeRabbit
4. **Polish**: Final verification and documentation

### Task Counts by User Story

| User Story | Task Count | Parallelizable |
|------------|------------|----------------|
| Setup | 4 | 3 |
| Foundational | 6 | 0 |
| US1 - Shell | 10 | 5 |
| US2 - Docker | 7 | 0 |
| US3 - AI Tools | 3 | 2 |
| US4 - Remote IDE | 7 | 1 |
| US5 - zellij | 2 | 0 |
| US6 - Git | 3 | 2 |
| US7 - npm/uv | 3 | 2 |
| US8 - Terraform | 2 | 0 |
| US9 - 1Password | 3 | 0 |
| US10 - CodeRabbit | 2 | 0 |
| Polish | 6 | 2 |
| **TOTAL** | **58** | **17** |

---

## Notes

- [P] tasks = different files, no dependencies on incomplete tasks
- [Story] label maps task to specific user story for traceability
- All NixOS modules must include constitution-aligned header comments
- Build verification (`nixos-rebuild build --flake .#devbox`) after each user story
- WSL configuration excludes Docker module (uses Docker Desktop on Windows host)
- Unfree packages (claude-code, terraform, _1password-cli) require allowUnfreePredicate
