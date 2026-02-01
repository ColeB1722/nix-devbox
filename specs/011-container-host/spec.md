# Feature Specification: Container Host

**Feature Branch**: `011-container-host`  
**Created**: 2025-01-31  
**Status**: Draft  
**Input**: User description: "Specialize devbox into a lean manager for podman containers with Tailscale SSH OAuth, scoped user permissions for container isolation, designed for safe agent development containers"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - SSH Access via Tailscale OAuth (Priority: P1)

A user authenticates to the container host via Tailscale SSH using their identity provider (e.g., Google, GitHub, Okta) rather than managing SSH keys in the repository. The system verifies their identity against Tailscale ACLs and grants appropriate access.

**Why this priority**: Authentication is the foundation — nothing else works without secure access. OAuth eliminates the security risk of committed public keys and centralizes identity management.

**Independent Test**: Can be fully tested by attempting SSH connection via Tailscale (`ssh user@hostname`) and verifying OAuth flow completes successfully, granting shell access.

**Acceptance Scenarios**:

1. **Given** a user is authenticated to Tailscale with a valid identity, **When** they SSH to the container host, **Then** they are granted shell access without requiring a pre-configured SSH public key
2. **Given** a user is not authenticated to Tailscale, **When** they attempt SSH to the container host, **Then** connection is refused
3. **Given** a user's Tailscale ACL does not permit access to the host, **When** they attempt SSH, **Then** connection is denied

---

### User Story 2 - User-Scoped Container Isolation (Priority: P1)

A non-admin user can create, start, stop, and delete their own Podman containers. They cannot see, access, or affect containers belonging to other users. Each user operates in an isolated container namespace.

**Why this priority**: Multi-tenancy and isolation are core to the feature — users running AI agents need confidence their containers are sandboxed from others.

**Independent Test**: Can be tested by creating containers as two different users and verifying neither can list or interact with the other's containers.

**Acceptance Scenarios**:

1. **Given** user A has running containers, **When** user B lists containers, **Then** user B sees only their own containers (not user A's)
2. **Given** user A attempts to stop user B's container by ID, **When** the command executes, **Then** it fails with a permission error
3. **Given** a new user logs in for the first time, **When** they run container commands, **Then** their rootless Podman environment is automatically initialized

---

### User Story 3 - Minimal Host Attack Surface (Priority: P2)

The container host runs only essential services: SSH (via Tailscale), Podman socket, and system services. No web UIs, no code-server, no unnecessary packages. The firewall blocks all non-Tailscale traffic.

**Why this priority**: A lean host reduces attack surface for agent workloads. Fewer services = fewer vulnerabilities.

**Independent Test**: Can be tested by port scanning the host and verifying only expected services respond, and by reviewing installed packages against a minimal baseline.

**Acceptance Scenarios**:

1. **Given** the host is deployed, **When** a port scan is run from outside the Tailnet, **Then** no ports respond
2. **Given** the host is deployed, **When** a port scan is run from inside the Tailnet, **Then** only SSH (port 22) responds
3. **Given** the host configuration, **When** reviewing enabled services, **Then** only systemd essentials, Tailscale, and Podman are running

---

### User Story 4 - Container Resource Limits (Priority: P2)

Administrators can define per-user resource quotas (CPU, memory, storage) to prevent any single user or runaway agent from exhausting host resources.

**Why this priority**: Agent containers may consume unpredictable resources. Limits protect host stability and ensure fair sharing.

**Independent Test**: Can be tested by launching a container that attempts to exceed its memory limit and verifying it is killed/throttled.

**Acceptance Scenarios**:

1. **Given** a user has a 4GB memory quota, **When** their container attempts to allocate 8GB, **Then** the container is OOM-killed or allocation fails
2. **Given** a user has a 2 CPU core limit, **When** their container attempts CPU-intensive work, **Then** it is throttled to 2 cores maximum
3. **Given** a user has a 50GB storage quota, **When** their containers exceed this, **Then** new writes fail with "no space" error

---

### User Story 5 - Admin Container Oversight (Priority: P3)

Administrators can view all containers across all users for monitoring and troubleshooting. They can also forcibly stop or remove containers if needed.

**Why this priority**: Operational necessity for troubleshooting, but not required for basic functionality.

**Independent Test**: Can be tested by an admin listing all containers system-wide and stopping another user's container.

**Acceptance Scenarios**:

1. **Given** an admin user, **When** they list all containers, **Then** they see containers from all users with owner attribution
2. **Given** a runaway container from user A, **When** an admin forcibly stops it, **Then** the container stops and user A is notified (via container state)

---

### Edge Cases

- What happens when a user's Tailscale session expires mid-SSH session? (Session continues until disconnect; new connections require re-auth)
- How does the system handle Podman socket conflicts between users? (Each user has their own rootless Podman socket)
- What happens if Tailscale service is down? (No SSH access possible; host is unreachable)
- What if a user tries to mount host paths into their container? (Restricted to user's home directory and designated shared volumes only)
- What happens when an agent spawns containers recursively? (Nested containers disabled; Podman-in-Podman not permitted by default)

## Requirements *(mandatory)*

### Functional Requirements

**Authentication & Access**
- **FR-001**: System MUST authenticate SSH connections exclusively via Tailscale SSH with OAuth identity providers
- **FR-002**: System MUST NOT accept traditional SSH public key authentication from committed keys
- **FR-003**: System MUST enforce Tailscale ACLs for SSH access decisions
- **FR-004**: System MUST support multiple identity providers via Tailscale (Google, GitHub, Okta, etc.)

**Container Isolation**
- **FR-005**: System MUST run Podman in rootless mode for all non-admin users
- **FR-006**: System MUST isolate each user's containers in separate namespaces (user cannot see other users' containers)
- **FR-007**: System MUST prevent users from accessing other users' container storage
- **FR-008**: System MUST automatically initialize rootless Podman for new users on first login
- **FR-009**: System MUST restrict container volume mounts to user's home directory and explicitly permitted paths

**Resource Management**
- **FR-010**: System MUST support configurable per-user CPU limits
- **FR-011**: System MUST support configurable per-user memory limits
- **FR-012**: System MUST support configurable per-user storage quotas
- **FR-013**: System MUST enforce resource limits via cgroups v2

**Security Hardening**
- **FR-014**: System MUST block all network traffic not originating from Tailscale interface
- **FR-015**: System MUST disable Podman-in-Podman (nested containers) by default
- **FR-016**: System MUST run minimal services (no code-server, ttyd, syncthing, or web UIs)
- **FR-017**: System MUST log all container lifecycle events (create, start, stop, delete) with user attribution

**Administration**
- **FR-018**: Admin users MUST be able to list all containers across all users
- **FR-019**: Admin users MUST be able to stop/remove any user's containers
- **FR-020**: System MUST provide container resource usage metrics per user

### Key Entities

- **User**: Identity authenticated via Tailscale OAuth; has resource quotas; owns zero or more containers
- **Container**: Podman container owned by exactly one user; subject to user's resource limits; isolated from other users' containers
- **Resource Quota**: Per-user limits for CPU cores, memory (GB), and storage (GB); enforced by cgroups and filesystem quotas
- **Tailscale ACL**: External policy defining which identities can SSH to which hosts; managed outside this system

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can SSH to the host within 5 seconds of initiating Tailscale OAuth flow
- **SC-002**: Container isolation verified: 0% of cross-user container access attempts succeed
- **SC-003**: Host runs fewer than 15 system services (excluding kernel threads)
- **SC-004**: Resource limits enforced: 100% of over-quota operations are blocked/throttled
- **SC-005**: New user can launch their first container within 60 seconds of first SSH login
- **SC-006**: Admin can identify and stop a problematic container within 30 seconds
- **SC-007**: Host accepts 0 connections on non-Tailscale interfaces

## Assumptions

- Tailscale is already configured with appropriate ACLs in the Tailscale admin console
- Users have Tailscale client installed and authenticated on their local machines
- The host has cgroups v2 enabled (standard on NixOS 25.05)
- Filesystem supports quotas (ext4/xfs/btrfs with quota enabled)
- Container images are pulled from public registries or a shared internal registry (image distribution is out of scope)