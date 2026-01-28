# Feature Specification: Multi-Platform Development Environment

> **⚠️ ARCHIVED**: This feature was implemented and subsequently removed from the codebase to establish a minimal foundation. The spec is preserved for documentation and potential future reimplementation. See `containers/` for the preserved container image definitions.

**Feature Branch**: `009-devcontainer-orchestrator`  
**Created**: 2025-01-25  
**Status**: Removed (archived for reference)  
**Input**: Multi-platform development environment with 4 host configurations: headless orchestrator (NixOS), dev containers (dockertools), macOS workstation (nix-darwin), and headful NixOS desktop.
**Depends On**: `008-extended-devtools` (Podman, CLI tools, Hyprland foundation)

## Clarifications

### Session 2025-01-25

- Q: Which secrets manager(s) must be supported for retrieving Tailscale auth keys? → A: 1Password CLI (`op`) only
- Q: How should dev containers be uniquely identified/named? → A: User-chosen freeform name (validated for uniqueness)
- Q: What are the concurrency limits for dev containers? → A: Both limits: max 5 containers per user, max 7 containers global (based on 32GB RAM / 32 thread host)
- Q: What are the default CPU and memory limits per container? → A: Standard: 2 CPU cores, 4GB RAM
- Q: How should the system handle orphaned/idle containers? → A: Auto-stop after 7 days idle, auto-destroy after 14 days stopped
- Q: How should file sync between containers and local workstations be handled? → A: Optional Syncthing inside container (not on orchestrator), user pairs local Syncthing to container over Tailscale
- Q: How should 1Password authentication work on the orchestrator? → A: Single global Service Account token (OP_SERVICE_ACCOUNT_TOKEN), not per-user logins
- Q: What Tailscale tags should containers receive? → A: All containers get `tag:devcontainer` + user-specific `tag:{username}-container` for ACL isolation
- Q: How should per-user auth keys be organized in 1Password? → A: Items named `{username}-tailscale-authkey` in a shared vault (consumer-configurable vault name)

## Overview

This feature establishes a complete multi-platform development environment ecosystem with four distinct host configurations. Each configuration serves a specific use case while sharing a common foundation of development tools and practices.

### Host Configurations

| Host Type | Platform | Primary Use Case | Access Method |
|-----------|----------|------------------|---------------|
| **Orchestrator** | NixOS (bare-metal + WSL2) | Headless server managing dev containers | SSH (key auth) |
| **Dev Container** | Container (dockertools) | Remote agentic development environment | Tailscale SSH, code-server, Zed remote |
| **macOS Workstation** | nix-darwin | Local development with tiling | Direct (local) |
| **Headful NixOS** | NixOS (bare-metal only) | Desktop development with tiling | Direct (local) |

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        Development Environment Ecosystem                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    ORCHESTRATOR HOST (NixOS)                         │   │
│  │                    [Bare-metal VM or WSL2]                           │   │
│  │                                                                      │   │
│  │   ┌──────────────┐  ┌──────────────┐  ┌──────────────┐              │   │
│  │   │   SSH (22)   │  │  Git / GH    │  │   Secrets    │              │   │
│  │   │  Key Auth    │  │  Repo Mgmt   │  │   Manager    │              │   │
│  │   └──────────────┘  └──────────────┘  └──────────────┘              │   │
│  │                                                                      │   │
│  │   ┌──────────────────────────────────────────────────────────────┐  │   │
│  │   │  Container Orchestration (Podman)                            │  │   │
│  │   │                                                              │  │   │
│  │   │   ┌────────────┐  ┌────────────┐  ┌────────────┐            │  │   │
│  │   │   │ Dev Cont.  │  │ Dev Cont.  │  │ Dev Cont.  │            │  │   │
│  │   │   │  (User A)  │  │  (User B)  │  │  (User C)  │            │  │   │
│  │   │   │            │  │            │  │            │            │  │   │
│  │   │   │ Tailscale  │  │ Tailscale  │  │ Tailscale  │            │  │   │
│  │   │   │ code-server│  │ code-server│  │ code-server│            │  │   │
│  │   │   │ Zed remote │  │ Zed remote │  │ Zed remote │            │  │   │
│  │   │   └────────────┘  └────────────┘  └────────────┘            │  │   │
│  │   │                                                              │  │   │
│  │   └──────────────────────────────────────────────────────────────┘  │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────┐  ┌─────────────────────────────────────┐  │
│  │   macOS WORKSTATION        │  │   HEADFUL NixOS DESKTOP             │  │
│  │   [nix-darwin]             │  │   [Bare-metal only]                 │  │
│  │                            │  │                                     │  │
│  │   • Full CLI tooling       │  │   • Full CLI tooling                │  │
│  │   • Aerospace tiling       │  │   • Hyprland tiling                 │  │
│  │   • Local development      │  │   • Local development               │  │
│  │   • Future: Obsidian, etc  │  │   • On-metal deployments            │  │
│  └─────────────────────────────┘  └─────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Spin Up a Dev Container (Priority: P1)

As a developer, I want to request an isolated dev container from the orchestrator so I can have a fully-featured remote development environment with my own identity and credentials.

**Why this priority**: Core value proposition — enables remote agentic development with per-user isolation.

**Independent Test**: Developer SSHs to orchestrator, runs container creation command with their Tailscale auth key, and receives a running container they can immediately access.

**Acceptance Scenarios**:

1. **Given** I have SSH key access to the orchestrator, **When** I run the container creation command with my Tailscale auth key, **Then** a new dev container is created and joins my tailnet
2. **Given** my container is running, **When** I connect via `ssh user@container.tailnet`, **Then** I'm authenticated via my Tailscale identity
3. **Given** my container is running, **When** I open code-server or Zed remote, **Then** I have a full IDE experience with all CLI tools available
4. **Given** I already have a running container, **When** I request another, **Then** I'm informed of my existing container with option to create additional

---

### User Story 2 - Deploy Orchestrator Host (Priority: P1)

As a platform administrator, I want to deploy the orchestrator on either bare-metal VM or WSL2 so I can provide dev containers to my team regardless of my infrastructure.

**Why this priority**: Foundation for all container-based development — must work on both target platforms.

**Independent Test**: Administrator deploys NixOS configuration, can SSH in, and Podman is operational.

**Acceptance Scenarios**:

1. **Given** I have a bare-metal VM, **When** I deploy the orchestrator configuration, **Then** the system boots with SSH access and Podman ready
2. **Given** I have WSL2 on Windows, **When** I deploy the orchestrator configuration, **Then** the system runs with SSH access and Podman ready
3. **Given** the orchestrator is running, **When** I authenticate via SSH key, **Then** I have access to container management commands
4. **Given** I need to manage repositories, **When** I use git/gh commands, **Then** I can clone, push, and manage repos on behalf of users

---

### User Story 3 - Manage Container Lifecycle (Priority: P2)

As a developer, I want to stop, start, and destroy my dev containers so I can manage resources and clean up when done.

**Why this priority**: Essential for resource management, but secondary to initial creation and access.

**Independent Test**: Developer can stop their container, restart it later with state preserved, and destroy it when finished.

**Acceptance Scenarios**:

1. **Given** my container is running, **When** I run the stop command, **Then** the container stops but preserves state
2. **Given** my container is stopped, **When** I run the start command, **Then** the container resumes with my previous state
3. **Given** I want to clean up, **When** I run the destroy command, **Then** the container and its Tailscale registration are removed
4. **Given** the orchestrator reboots, **When** my container was running before, **Then** it auto-restarts

---

### User Story 4 - Use macOS Workstation (Priority: P2)

As a developer on macOS, I want a fully-configured local development environment with tiling window management so I can work efficiently without remote dependencies.

**Why this priority**: Enables local development workflow for macOS users with same tooling as remote environments.

**Independent Test**: Developer applies nix-darwin configuration, has full CLI tooling, and Aerospace tiling works.

**Acceptance Scenarios**:

1. **Given** I have a Mac, **When** I apply the nix-darwin configuration, **Then** all CLI development tools are available
2. **Given** the configuration is applied, **When** I use Aerospace, **Then** I have functional tiling window management
3. **Given** I'm developing locally, **When** I use the CLI tools, **Then** they behave identically to the remote dev container environment
4. **Given** I want additional apps, **When** future updates include apps like Obsidian, **Then** they are installed and configured

---

### User Story 5 - Use Headful NixOS Desktop (Priority: P3)

As a developer preferring Linux desktop, I want a fully-configured NixOS workstation with Hyprland tiling so I can have a native Linux development experience.

**Why this priority**: Completes the platform coverage but targets smaller audience than macOS or remote containers.

**Independent Test**: Developer deploys headful NixOS on bare-metal, has full CLI tooling, and Hyprland provides tiling.

**Acceptance Scenarios**:

1. **Given** I have bare-metal hardware, **When** I deploy the headful NixOS configuration, **Then** the system boots into Hyprland with all CLI tools
2. **Given** I'm using Hyprland, **When** I manage windows, **Then** tiling behaves as configured
3. **Given** I'm developing locally, **When** I use the CLI tools, **Then** they behave identically to other platform configurations

---

### User Story 6 - Per-User Secrets and Tagging (Priority: P2)

As a platform administrator, I want each user's dev container to have unique Tailscale tags and credentials from a secrets manager so containers are properly identified and isolated on the tailnet.

**Why this priority**: Security and identity isolation are critical for multi-user environments.

**Independent Test**: Two users create containers, each container has unique Tailscale tags matching their identity.

**Acceptance Scenarios**:

1. **Given** User A creates a container, **When** they provide their auth key, **Then** the container joins tailnet with User A's tags
2. **Given** User B creates a container, **When** they provide their auth key, **Then** the container joins tailnet with User B's tags (different from A)
3. **Given** auth keys are stored in secrets manager, **When** container is created, **Then** the key is retrieved securely without exposure in logs or config
4. **Given** User A's container exists, **When** User B tries to SSH to it, **Then** Tailscale ACLs deny access

---

### User Story 7 - Sync Files Between Container and Local Workstation (Priority: P3)

As a developer, I want to optionally enable file synchronization in my dev container so I can work on files locally (offline) and have them sync to my container when connected.

**Why this priority**: Enhances workflow flexibility but core development works without it via SSH/Zed/code-server.

**Independent Test**: Developer creates container with `--with-syncthing`, pairs local Syncthing, edits file locally, file appears in container within seconds.

**Acceptance Scenarios**:

1. **Given** I create a container with `--with-syncthing`, **When** the container starts, **Then** Syncthing daemon is running and accessible via Tailscale
2. **Given** Syncthing is running in my container, **When** I open the Syncthing GUI at `http://container.tailnet:8384`, **Then** I can pair my local Syncthing instance
3. **Given** I've paired my local Syncthing to the container, **When** I create a file in `~/Sync` on my Mac, **Then** it appears in `/home/dev/sync` in the container within seconds
4. **Given** I edit a file in `/home/dev/sync` in the container, **When** Syncthing syncs, **Then** the changes appear in `~/Sync` on my Mac
5. **Given** my container is stopped, **When** I edit files locally, **Then** they sync when the container restarts
6. **Given** I destroy my container but keep the volume, **When** I create a new container with `--with-syncthing` using the same volume, **Then** Syncthing config is preserved and sync resumes

---

### Edge Cases

- What happens when the orchestrator runs out of resources (CPU, memory, disk)?
- What happens when a user's Tailscale auth key expires while container is running?
- Orphaned containers: Auto-stop after 7 days idle, auto-destroy after 14 days stopped (with user notification)
- What happens if Tailscale service fails inside the container?
- How do containers get network access for package downloads?
- What happens during orchestrator reboot — do containers auto-restart?
- What happens if secrets manager is unavailable during container creation?
- How does WSL2 deployment differ from bare-metal (networking, storage)?
- What happens when macOS system updates conflict with nix-darwin configuration?
- How are Hyprland configuration conflicts resolved on headful NixOS?
- What happens if Syncthing conflicts occur (same file edited in container and locally)?
- How does Syncthing behave when container is stopped for extended periods then restarted?

## Requirements *(mandatory)*

### Functional Requirements

#### Orchestrator Host (NixOS)
- **FR-001**: Orchestrator MUST deploy on both bare-metal VM and WSL2 platforms
- **FR-002**: Orchestrator MUST provide SSH access with public key authentication only
- **FR-003**: Orchestrator MUST run Podman for rootless container management
- **FR-004**: Orchestrator MUST provide git and gh CLI for repository management
- **FR-005**: Orchestrator MUST have minimal NixOS configuration (headless, no GUI)

#### Dev Containers
- **FR-006**: Dev containers MUST be built using dockertools (Nix-native container images)
- **FR-007**: Dev containers MUST include full CLI tooling from the shared development profile
- **FR-008**: Dev containers MUST run Tailscale daemon and enable Tailscale SSH
- **FR-009**: Dev containers MUST include code-server for browser-based IDE access
- **FR-010**: Dev containers MUST include Zed remote server for Zed editor integration
- **FR-011**: Dev containers MUST accept user-provided Tailscale auth key at creation
- **FR-012**: Dev containers MUST support different Tailscale tags per user
- **FR-013**: Dev containers MUST have persistent storage for user data across restarts

#### File Synchronization (Optional)
- **FR-037**: Dev containers MAY be created with Syncthing enabled via `--with-syncthing` flag
- **FR-038**: When Syncthing is enabled, container MUST run Syncthing daemon with GUI on port 8384 and sync on port 22000
- **FR-039**: Syncthing ports MUST be accessible only via Tailscale (not exposed to public network)
- **FR-040**: Syncthing MUST sync the `/home/dev/sync` directory inside the container
- **FR-041**: Users MUST pair their local Syncthing instance to the container manually (one-time setup per container)
- **FR-042**: Syncthing configuration MUST persist in the container's volume across restarts
- **FR-043**: Orchestrator host MUST NOT run Syncthing (sync is container-only to maintain minimalism)

#### Secrets Management
- **FR-014**: System MUST retrieve per-user Tailscale auth keys from 1Password using the `op` CLI
- **FR-015**: System MUST NOT expose auth keys in logs, environment variables visible to other users, or configuration files
- **FR-016**: System MUST support auth key rotation without container recreation
- **FR-044**: Orchestrator MUST use a single 1Password Service Account token for all secret retrieval (not per-user logins)
- **FR-045**: Service Account token MUST be provided via `OP_SERVICE_ACCOUNT_TOKEN` environment variable (systemd credential or equivalent)
- **FR-046**: 1Password item naming MUST follow convention: `{username}-tailscale-authkey`
- **FR-047**: 1Password reference format MUST be: `op://{vault}/{username}-tailscale-authkey/password`
- **FR-048**: Vault name MUST be configurable by consumer in their `users.nix` (default: `DevBox`)

#### Tailscale Tags & ACLs
- **FR-049**: All dev containers MUST receive tag `tag:devcontainer` for common ACL rules
- **FR-050**: Each user's containers MUST receive tag `tag:{username}-container` for user-specific ACL isolation
- **FR-051**: Tailscale auth keys MUST be created with `reusable=true` and `ephemeral=true`
- **FR-052**: Tailscale ACL management is OUT OF SCOPE (handled in consumer's homelab-iac or equivalent)

#### macOS Workstation (nix-darwin)
- **FR-017**: macOS configuration MUST provide full CLI tooling matching dev container environment
- **FR-018**: macOS configuration MUST include Aerospace for tiling window management
- **FR-019**: macOS configuration MUST NOT include remote access components (code-server, Zed remote, Tailscale SSH)
- **FR-020**: macOS configuration MUST support future expansion to installable applications (e.g., Obsidian)

#### Headful NixOS Desktop
- **FR-021**: Headful NixOS MUST deploy on bare-metal only (not WSL2 or VM without GPU passthrough)
- **FR-022**: Headful NixOS MUST include Hyprland for tiling window management
- **FR-023**: Headful NixOS MUST provide full CLI tooling matching other platforms
- **FR-024**: Headful NixOS MUST NOT include remote access components

#### Container Lifecycle
- **FR-025**: Users MUST be able to create, stop, start, and destroy their containers
- **FR-026**: Users MUST only be able to manage their own containers
- **FR-030**: Container names MUST be user-chosen freeform strings validated for uniqueness across the orchestrator
- **FR-031**: Container names MUST be validated against naming rules (alphanumeric, hyphens, no spaces, reasonable length)
- **FR-027**: Containers MUST auto-restart after orchestrator reboot
- **FR-028**: Container destruction MUST remove Tailscale device registration
- **FR-029**: System MUST enforce default resource limits of 2 CPU cores and 4GB RAM per container
- **FR-032**: System MUST enforce a maximum of 5 concurrent containers per user
- **FR-033**: System MUST enforce a maximum of 7 concurrent containers globally on the orchestrator
- **FR-034**: System MUST auto-stop containers after 7 days of idle activity
- **FR-035**: System MUST auto-destroy stopped containers after 14 days
- **FR-036**: System SHOULD notify users before auto-stop and auto-destroy actions

### Key Entities

- **Orchestrator Host**: The NixOS server (bare-metal or WSL2) that manages dev containers and provides SSH access
- **Dev Container**: An isolated container with full development tooling and Tailscale-based remote access, identified by a unique user-chosen name
- **Container Name**: A unique, user-chosen identifier for a dev container (alphanumeric with hyphens, validated for uniqueness)
- **Tailscale Auth Key**: A per-user credential stored in 1Password as `{username}-tailscale-authkey`, allows container to join tailnet with tags `tag:devcontainer` and `tag:{username}-container`
- **User**: A person with SSH key access to the orchestrator who can request and manage containers
- **Sync Folder**: The `/home/dev/sync` directory inside a Syncthing-enabled container, bidirectionally synced with the user's local workstation
- **Container Image**: The dockertools-built image containing development tools, code-server, Zed remote, and Tailscale
- **1Password Service Account**: A system-wide credential (not user-specific) that allows the orchestrator to read auth keys from a shared vault
- **1Password Vault**: Consumer-configured vault (default: `DevBox`) containing all users' Tailscale auth keys
- **macOS Workstation**: A local development environment on macOS using nix-darwin
- **Headful Desktop**: A local development environment on NixOS with Hyprland GUI

## Success Criteria *(mandatory)*

### Measurable Outcomes

#### Orchestrator & Containers
- **SC-001**: Orchestrator deployment completes in under 15 minutes on both bare-metal and WSL2
- **SC-002**: Container creation completes in under 60 seconds from request
- **SC-003**: Tailscale SSH connection to container establishes in under 5 seconds
- **SC-004**: Container stop/start cycle completes in under 10 seconds
- **SC-005**: 100% of container destructions result in Tailscale device cleanup
- **SC-006**: Containers survive orchestrator reboot (auto-restart within 60 seconds)
- **SC-007**: Users cannot access other users' containers (ACL enforcement verified)

#### Platform Parity
- **SC-008**: All CLI tools available in dev containers are also available on macOS and headful NixOS
- **SC-009**: Developer can switch between platforms without relearning tooling
- **SC-010**: Configuration changes to shared CLI tools propagate to all platforms

#### Security
- **SC-011**: No secrets exposed in container logs or orchestrator audit logs
- **SC-012**: SSH to orchestrator only succeeds with authorized public keys
- **SC-013**: Tailscale tags correctly applied per user (verified via Tailscale admin)

#### Workstation Deployments
- **SC-014**: macOS nix-darwin configuration applies without errors in under 10 minutes
- **SC-015**: Headful NixOS boots to Hyprland desktop in under 60 seconds
- **SC-016**: Aerospace tiling on macOS responds to hotkeys within 100ms

## Assumptions

- Podman is available from 008-extended-devtools (already implemented)
- Hyprland module exists from 008-extended-devtools (already implemented)
- Users have Tailscale accounts and can generate auth keys
- 1Password CLI (`op`) is installed on the orchestrator
- 1Password Service Account is created with read access to the configured vault
- `OP_SERVICE_ACCOUNT_TOKEN` is securely provided to the orchestrator (via systemd credential, agenix, or equivalent)
- Per-user items `{username}-tailscale-authkey` exist in the 1Password vault
- Tailscale auth keys are created with appropriate tags (`tag:devcontainer`, `tag:{username}-container`)
- Tailscale ACLs are managed externally (e.g., in homelab-iac) to enforce user isolation
- macOS users have Nix installed (via Determinate Systems installer or similar)
- Bare-metal headful deployments have compatible GPU for Hyprland
- WSL2 deployments use WSL2 with systemd support enabled

## Library vs Consumer Responsibilities

This specification describes **nix-devbox** as a reusable flake library. The separation of concerns:

### nix-devbox (this repo) provides:
- NixOS/darwin modules and Home Manager profiles
- Schema validation for user data (`lib/schema.nix`)
- Conventions for 1Password item naming and Tailscale tags
- Container image definitions and `devbox-ctl` CLI
- Example/placeholder data (`examples/users.nix`)

### Consumer (private repo) provides:
- Actual user data (`users.nix` with real names, UIDs, SSH keys)
- 1Password vault name configuration
- 1Password Service Account token (securely stored)
- Tailscale auth keys in 1Password (via Terraform or CLI)
- Tailscale ACLs for user isolation (in homelab-iac or equivalent)
- Hardware configuration for their machines

## Out of Scope (for this feature)

- Web UI for container management
- Container scaling / load balancing
- Container networking between users (each container is isolated)
- Custom container images per user (single base image for now)
- Integration with identity providers beyond Tailscale
- Tailscale ACL management (handled in separate homelab-iac repo)
- Mobile device configurations
- Automated container image updates/rebuilds