# Feature Specification: Dev Container Orchestrator

**Feature Branch**: `009-devcontainer-orchestrator`  
**Created**: 2026-01-25  
**Status**: Draft  
**Input**: User description: "Lightweight dev container orchestrator with per-user Tailscale SSH authentication"
**Depends On**: `008-extended-devtools` (Podman installation)

## Overview

A lightweight orchestration layer on NixOS that allows users to spin up isolated development containers via Podman. Each container runs Tailscale SSH, enabling users to authenticate with their own Tailscale identity for secure, convenient access without managing SSH keys.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         NixOS Host (Orchestrator)                   │
│                                                                     │
│   ┌─────────────────────────────────────────────────────────────┐   │
│   │  Traditional SSH (port 22)                                  │   │
│   │  - Hardcoded public keys in Nix config                      │   │
│   │  - Used by: Admins, CI/CD, orchestration commands           │   │
│   └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
│   ┌─────────────────────────────────────────────────────────────┐   │
│   │  Orchestrator Service                                       │   │
│   │  - Receives container requests                              │   │
│   │  - Manages container lifecycle (create, start, stop, destroy)│   │
│   │  - Injects user's Tailscale auth key into container         │   │
│   └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
│   ┌─────────────────────────────────────────────────────────────┐   │
│   │  Podman (rootless)                                          │   │
│   │                                                             │   │
│   │   ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │   │
│   │   │ Dev Container│  │ Dev Container│  │ Dev Container│     │   │
│   │   │   (User A)   │  │   (User B)   │  │   (User C)   │     │   │
│   │   │              │  │              │  │              │     │   │
│   │   │ - Tailscale  │  │ - Tailscale  │  │ - Tailscale  │     │   │
│   │   │ - Dev tools  │  │ - Dev tools  │  │ - Dev tools  │     │   │
│   │   │ - User env   │  │ - User env   │  │ - User env   │     │   │
│   │   └──────────────┘  └──────────────┘  └──────────────┘     │   │
│   │                                                             │   │
│   └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Request a Dev Container (Priority: P1)

As a developer, I want to request a dev container on the orchestrator so I can have an isolated development environment with my preferred tools.

**Why this priority**: Core functionality — without this, there's no orchestrator.

**Independent Test**: User SSHs to host, runs command, and a container is created for them.

**Acceptance Scenarios**:

1. **Given** I have SSH access to the host, **When** I run the container request command, **Then** a new dev container is created for me
2. **Given** a container is being created, **When** creation completes, **Then** I receive connection instructions (Tailscale hostname)
3. **Given** I already have a running container, **When** I request another, **Then** I'm informed of my existing container (or option to create additional)

---

### User Story 2 - Authenticate via Tailscale SSH (Priority: P1)

As a developer, I want to SSH into my dev container using my Tailscale identity so I can access my environment without managing SSH keys.

**Why this priority**: Core value proposition — frictionless, secure authentication.

**Independent Test**: User runs `ssh user@container.tailnet` and authenticates via Tailscale.

**Acceptance Scenarios**:

1. **Given** my container is running with Tailscale, **When** I run `ssh user@container-name`, **Then** I'm authenticated via my Tailscale identity
2. **Given** I'm not authenticated to Tailscale, **When** I attempt SSH, **Then** I'm prompted to authenticate via browser
3. **Given** another user attempts to SSH to my container, **When** ACLs deny access, **Then** connection is refused

---

### User Story 3 - Container Lifecycle Management (Priority: P2)

As a developer, I want to stop, start, and destroy my dev containers so I can manage resources and clean up when done.

**Why this priority**: Essential for resource management, but secondary to initial creation and access.

**Independent Test**: User can stop, restart, and destroy their container via commands.

**Acceptance Scenarios**:

1. **Given** my container is running, **When** I run the stop command, **Then** the container stops (preserving state)
2. **Given** my container is stopped, **When** I run the start command, **Then** the container resumes
3. **Given** I want to clean up, **When** I run the destroy command, **Then** the container and its data are removed
4. **Given** I destroy my container, **When** I check Tailscale, **Then** the device is removed from my tailnet

---

### User Story 4 - Provide Tailscale Auth Key (Priority: P2)

As a developer, I want to provide my Tailscale auth key so my container can join the tailnet under my identity.

**Why this priority**: Required for Tailscale SSH to work, but the mechanism can vary.

**Independent Test**: User provides auth key, container joins tailnet with user's identity.

**Acceptance Scenarios**:

1. **Given** I'm requesting a container, **When** I provide my Tailscale auth key, **Then** the container uses it to join my tailnet
2. **Given** I provide an invalid auth key, **When** container tries to join, **Then** I receive a clear error message
3. **Given** my auth key is ephemeral, **When** the container joins, **Then** it's automatically removed from tailnet on disconnect

---

### User Story 5 - Persistent Development Environment (Priority: P3)

As a developer, I want my dev container to persist my work across restarts so I don't lose progress.

**Why this priority**: Important for usability, but the core MVP can work without persistence.

**Independent Test**: User creates files, stops container, restarts, files still exist.

**Acceptance Scenarios**:

1. **Given** I create files in my container, **When** I stop and start the container, **Then** my files persist
2. **Given** I install packages in my container, **When** I restart, **Then** packages are still installed
3. **Given** I destroy my container, **When** I create a new one, **Then** it starts fresh (no persistence)

---

### Edge Cases

- What happens when the host runs out of resources (CPU, memory, disk)?
- What happens when a user's Tailscale auth key expires while container is running?
- How are orphaned containers handled (user never destroys them)?
- What happens if Tailscale service fails inside the container?
- How do containers get network access for package downloads?
- What happens during host reboot — do containers auto-restart?

## Requirements *(mandatory)*

### Functional Requirements

#### Orchestrator Service
- **FR-001**: System MUST provide a command-line interface for container lifecycle management
- **FR-002**: System MUST create isolated Podman containers per user request
- **FR-003**: System MUST inject user-provided Tailscale auth key into container at creation
- **FR-004**: System MUST track which containers belong to which users
- **FR-005**: System MUST provide container status information to users

#### Container Configuration
- **FR-006**: Dev containers MUST run Tailscale daemon and enable Tailscale SSH
- **FR-007**: Dev containers MUST include base development tools (from 008-extended-devtools)
- **FR-008**: Dev containers MUST have network access for package installation
- **FR-009**: Dev containers MUST run as non-root user inside container
- **FR-010**: Dev containers MUST have persistent storage volume for user data

#### Authentication & Access Control
- **FR-011**: Host access MUST use traditional SSH with hardcoded public keys
- **FR-012**: Container access MUST use Tailscale SSH with user's Tailscale identity
- **FR-013**: Users MUST only be able to manage their own containers
- **FR-014**: Tailscale ACLs MUST restrict SSH access to container owner only

#### Resource Management
- **FR-015**: System MUST enforce resource limits per container (CPU, memory)
- **FR-016**: System MUST clean up Tailscale device registration when container is destroyed
- **FR-017**: System SHOULD auto-stop idle containers after configurable timeout

### Key Entities

- **DevContainer**: An isolated Podman container with Tailscale SSH, belonging to a specific user
- **User**: A person with SSH access to the host who can request containers
- **TailscaleAuthKey**: A user-provided key that allows a container to join their tailnet
- **ContainerImage**: The base image used for dev containers (includes tools, Tailscale)
- **Volume**: Persistent storage attached to a container for user data

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Container creation completes in under 60 seconds from request
- **SC-002**: Tailscale SSH connection to container establishes in under 5 seconds
- **SC-003**: Container stop/start cycle completes in under 10 seconds
- **SC-004**: 100% of container destructions result in Tailscale device cleanup
- **SC-005**: No configuration errors during `nixos-rebuild` with orchestrator enabled
- **SC-006**: Users cannot access other users' containers (ACL enforcement)
- **SC-007**: Containers survive host reboot (auto-restart)
- **SC-008**: Resource limits prevent any single container from exhausting host resources

## Assumptions

- Podman is installed and configured (dependency on 008-extended-devtools)
- Users have Tailscale accounts and can generate auth keys
- Host has sufficient resources for multiple concurrent containers
- Tailscale ACLs are managed externally (e.g., in homelab-iac)
- Container image is pre-built and available (not built on-demand)

## Open Questions

1. **Auth key delivery**: How do users securely provide their Tailscale auth key? (CLI argument, file, environment variable?)
2. **Container image source**: Build custom image with Nix, or use existing image with Tailscale added?
3. **Orchestrator interface**: Simple shell scripts, or a more structured CLI tool?
4. **Multi-container per user**: Should users be allowed multiple containers simultaneously?
5. **Resource defaults**: What are sensible default CPU/memory limits per container?

## Out of Scope (for this feature)

- Web UI for container management
- Container scaling / load balancing
- Container networking between users (each container is isolated)
- Custom container images per user (single base image for now)
- Integration with external identity providers beyond Tailscale