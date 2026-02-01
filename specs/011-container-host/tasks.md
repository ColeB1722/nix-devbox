# Tasks: Container Host

**Input**: Design documents from `/specs/011-container-host/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, quickstart.md ✅

**Tests**: No automated tests requested. Validation via manual testing per quickstart.md.

**Organization**: Tasks grouped by user story for independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1-US5)
- Paths relative to repository root

---

## Phase 1: Setup

**Purpose**: Create new host and module files

- [x] T001 Create host directory structure at `hosts/container-host/`
- [x] T002 [P] Create empty module file at `nixos/tailscale-ssh.nix`
- [x] T003 [P] Create empty module file at `nixos/podman-isolation.nix`
- [x] T004 [P] Create empty module file at `home/modules/podman-user.nix`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Schema extension and base host definition — MUST complete before user stories

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T005 Extend `lib/schema.nix` with `resourceQuota` validator (cpuCores >= 1, memoryGB >= 1, storageGB >= 1, all optional)
- [x] T006 Add `resourceQuota` field handling to `nixos/users.nix` (read field, pass to systemd slice config)
- [x] T007 Update `examples/users.nix` with sample `resourceQuota` for `exampledev` user
- [x] T008 Create base `hosts/container-host/default.nix` importing only: `core.nix`, `ssh.nix`, `firewall.nix`, `tailscale.nix`, `fish.nix`, `users.nix`
- [x] T009 Add `container-host` to `flake.nix` nixosConfigurations

**Checkpoint**: Host builds with `nix build .#nixosConfigurations.container-host.config.system.build.toplevel` (no new features yet)

---

## Phase 3: User Story 1 - SSH Access via Tailscale OAuth (Priority: P1) 🎯 MVP

**Goal**: Users authenticate via Tailscale SSH OAuth — no committed SSH keys required

**Independent Test**: `ssh user@container-host` via Tailnet completes OAuth flow and grants shell access

### Implementation for User Story 1

- [x] T010 [US1] Implement `nixos/tailscale-ssh.nix` module with `devbox.tailscale.ssh.enable` option
- [x] T011 [US1] In `tailscale-ssh.nix`: Set `services.tailscale.ssh.enable = true` when option enabled
- [x] T012 [US1] In `tailscale-ssh.nix`: Configure `services.openssh` to bind only to `tailscale0` interface (or disable entirely, letting Tailscale handle SSH)
- [x] T013 [US1] In `tailscale-ssh.nix`: Add assertion that `devbox.tailscale.enable` must be true when SSH enabled
- [x] T014 [US1] Import `tailscale-ssh.nix` in `hosts/container-host/default.nix`
- [x] T015 [US1] Set `devbox.tailscale.ssh.enable = true` in container-host defaults
- [x] T016 [US1] Update firewall config in container-host to trust only `tailscale0` interface
- [x] T017 [US1] Add inline documentation explaining Tailscale ACL requirements (external config)

**Checkpoint**: Deploy, tag host with `tailscale up --advertise-tags=tag:container-host`, verify OAuth SSH works

---

## Phase 4: User Story 2 - User-Scoped Container Isolation (Priority: P1)

**Goal**: Each user's containers are isolated — cannot see or affect other users' containers

**Independent Test**: User A creates container, User B runs `podman ps` and sees nothing

### Implementation for User Story 2

- [x] T018 [US2] Implement `nixos/podman-isolation.nix` module with `devbox.podman.isolation.enable` option
- [x] T019 [US2] In `podman-isolation.nix`: Enable rootless Podman (`virtualisation.podman.enable = true`)
- [x] T020 [US2] In `podman-isolation.nix`: Disable `dockerCompat` to avoid socket conflicts
- [x] T021 [US2] In `podman-isolation.nix`: Configure subuid/subgid ranges per user (65536 range each, starting at 100000 + uid*65536)
- [x] T022 [US2] In `podman-isolation.nix`: Enable user lingering for all users (`loginctl enable-linger`)
- [x] T023 [US2] Implement `home/modules/podman-user.nix` for user-level Podman socket activation
- [x] T024 [US2] In `podman-user.nix`: Add `systemd.user.services.podman-init` to run `podman system migrate` on first login
- [x] T025 [US2] In `podman-user.nix`: Configure XDG paths for container storage (`~/.local/share/containers`)
- [x] T026 [US2] Import `podman-isolation.nix` in `hosts/container-host/default.nix`
- [x] T027 [US2] Set `devbox.podman.isolation.enable = true` in container-host defaults
- [x] T028 [US2] Create user profile that imports `podman-user.nix` for container-host users

**Checkpoint**: SSH as two different users, create containers as each, verify isolation

---

## Phase 5: User Story 3 - Minimal Host Attack Surface (Priority: P2)

**Goal**: Host runs <15 services, firewall blocks all non-Tailscale traffic

**Independent Test**: Port scan from outside Tailnet returns nothing; `systemctl list-units --type=service --state=running | wc -l` < 15

### Implementation for User Story 3

- [x] T029 [US3] Review and remove any unnecessary imports from `hosts/container-host/default.nix`
- [x] T030 [US3] Explicitly set `devbox.ttyd.enable = false` in container-host
- [x] T031 [US3] Explicitly set `devbox.syncthing.enable = false` in container-host
- [x] T032 [US3] Explicitly set `devbox.hyprland.enable = false` in container-host
- [x] T033 [US3] Do NOT import `code-server.nix` in container-host
- [x] T034 [US3] Configure firewall in container-host: `networking.firewall.enable = true`, `allowedTCPPorts = []`, `trustedInterfaces = ["tailscale0"]`
- [x] T035 [US3] Add comment documenting expected service count and how to verify

**Checkpoint**: Deploy, run service count check, run nmap from outside Tailnet

---

## Phase 6: User Story 4 - Container Resource Limits (Priority: P2)

**Goal**: Per-user CPU, memory, and storage quotas enforced via cgroups and filesystem

**Independent Test**: Container exceeds memory limit → OOM killed; container exceeds storage → ENOSPC

### Implementation for User Story 4

- [x] T036 [US4] In `nixos/users.nix`: Generate systemd slice config from `resourceQuota.cpuCores` (CPUQuota = cores * 100%)
- [x] T037 [US4] In `nixos/users.nix`: Generate systemd slice config from `resourceQuota.memoryGB` (MemoryMax = GB * 1073741824)
- [x] T038 [US4] In `podman-isolation.nix`: Add option `devbox.podman.isolation.enableQuotas` (default true on container-host)
- [x] T039 [US4] In `podman-isolation.nix`: Configure filesystem quota support (add `usrquota` to mount options documentation)
- [x] T040 [US4] In `podman-isolation.nix`: Add activation script to set filesystem quota from `resourceQuota.storageGB` using `setquota`
- [x] T041 [US4] Add assertion: if `resourceQuota` defined, user must not be admin (or warn)
- [x] T042 [US4] Update `examples/users.nix` with realistic quota values for non-admin user

**Checkpoint**: Create user with 1GB memory quota, run `stress --vm 1 --vm-bytes 2G` in container, verify OOM

---

## Phase 7: User Story 5 - Admin Container Oversight (Priority: P3)

**Goal**: Admins can view and manage all users' containers

**Independent Test**: Admin runs script to list all containers across users; admin stops another user's container

### Implementation for User Story 5

- [x] T043 [US5] Create admin helper script at `nixos/podman-isolation.nix` (environment.systemPackages or /usr/local/bin)
- [x] T044 [US5] Script `podman-admin-ps`: iterate users, run `sudo -u $user podman ps -a`, aggregate output
- [x] T045 [US5] Script `podman-admin-stop`: `sudo -u $1 podman stop $2` with validation
- [x] T046 [US5] Add scripts to container-host via `environment.systemPackages` (wrapped shell scripts)
- [x] T047 [US5] Document admin commands in module comments
- [x] T048 [US5] Ensure admin users (isAdmin=true) are in wheel group (already handled by users.nix)

**Checkpoint**: Admin SSH, run `podman-admin-ps`, see other users' containers

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, logging, final validation

- [x] T049 [P] Add container lifecycle logging via `journald` tagging in `podman-isolation.nix`
- [x] T050 [P] Update `AGENTS.md` with container-host specific notes if needed
- [x] T051 [P] Add `hardware-configuration.nix.example` to `hosts/container-host/` with `usrquota` mount option
- [x] T052 Review all new modules for inline documentation (Constitution Principle V)
- [ ] T053 Run full quickstart.md validation on deployed host
- [ ] T054 Verify all success criteria from spec.md (SC-001 through SC-007)

---

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1 (Setup)
    │
    ▼
Phase 2 (Foundational) ─── BLOCKS ALL USER STORIES
    │
    ├──► Phase 3 (US1: Tailscale SSH) ─┐
    │                                   │
    ├──► Phase 4 (US2: Isolation) ─────┼──► Phase 8 (Polish)
    │                                   │
    ├──► Phase 5 (US3: Minimal) ───────┤
    │                                   │
    ├──► Phase 6 (US4: Quotas) ────────┤
    │                                   │
    └──► Phase 7 (US5: Admin) ─────────┘
```

### User Story Dependencies

| Story | Depends On | Can Parallel With |
|-------|------------|-------------------|
| US1 (Tailscale SSH) | Phase 2 | US2, US3, US5 |
| US2 (Isolation) | Phase 2 | US1, US3, US5 |
| US3 (Minimal) | Phase 2 | US1, US2, US4, US5 |
| US4 (Quotas) | Phase 2, US2 (needs podman-isolation.nix) | US1, US3, US5 |
| US5 (Admin) | Phase 2, US2 (needs podman-isolation.nix) | US1, US3, US4 |

### Parallel Opportunities

Within Phase 1:
- T002, T003, T004 can run in parallel (different files)

Within Phase 2:
- T005, T006, T007 should be sequential (schema → users → example)
- T008, T009 can run after T005-T007

User Stories after Phase 2:
- US1 and US2 can run in parallel (different modules)
- US3 can run in parallel with any story
- US4 and US5 depend on US2's `podman-isolation.nix` existing

---

## Parallel Example: Setup Phase

```bash
# These can run simultaneously:
Task T002: "Create nixos/tailscale-ssh.nix"
Task T003: "Create nixos/podman-isolation.nix"  
Task T004: "Create home/modules/podman-user.nix"
```

## Parallel Example: After Foundational

```bash
# Developer A works on US1:
Task T010-T017: Tailscale SSH implementation

# Developer B works on US2:
Task T018-T028: Container isolation implementation

# These can merge independently
```

---

## Implementation Strategy

### MVP First (US1 + US2 Only)

1. Complete Phase 1: Setup (T001-T004)
2. Complete Phase 2: Foundational (T005-T009)
3. Complete Phase 3: US1 - Tailscale SSH (T010-T017)
4. Complete Phase 4: US2 - Isolation (T018-T028)
5. **STOP and VALIDATE**: Test OAuth SSH + container isolation
6. Deploy MVP — users can securely run isolated containers

### Full Implementation

1. MVP (above)
2. Add US3: Minimal attack surface (T029-T035)
3. Add US4: Resource quotas (T036-T042)
4. Add US5: Admin oversight (T043-T048)
5. Polish (T049-T054)

---

## Summary

| Metric | Value |
|--------|-------|
| Total Tasks | 54 |
| Phase 1 (Setup) | 4 tasks |
| Phase 2 (Foundational) | 5 tasks |
| US1 (Tailscale SSH) | 8 tasks |
| US2 (Isolation) | 11 tasks |
| US3 (Minimal) | 7 tasks |
| US4 (Quotas) | 7 tasks |
| US5 (Admin) | 6 tasks |
| Polish | 6 tasks |
| Parallel Opportunities | 12 tasks marked [P] |
| MVP Scope | US1 + US2 (28 tasks) |