# Feature Specification: Multi-User Support

**Feature Branch**: `006-multi-user-support`  
**Created**: 2026-01-18  
**Status**: Draft  
**Input**: User description: "I want the devbox to support multiple users, specifically the two authorized users in ../homelab-iac ColeB1722 and violinomaestro"

## Clarifications

### Session 2026-01-18

- Q: How should SSH public keys be managed (hardcoded vs injected)? → A: Environment variables at build time (injected via CI secrets or local env)
- Q: How should code-server handle multiple users? → A: Per-user instances on separate ports (Cole: 8080, Violino: 8081)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - coal accesses Devbox as Primary Admin (Priority: P1)

coal (ColeB1722@github) is the primary administrator of the devbox. He needs full access to the system including sudo privileges, all development tools, and the ability to manage the system. He connects via Tailscale SSH using his existing SSH key.

**Why this priority**: coal is the primary user and system administrator. The devbox must be fully functional for the admin before adding secondary users.

**Independent Test**: coal can SSH into the devbox, run sudo commands, use all development tools (fish, docker, code-server), and manage system configuration.

**Acceptance Scenarios**:

1. **Given** the devbox is deployed, **When** coal connects via SSH using his authorized key, **Then** he is logged into his user account with full shell access
2. **Given** coal is logged in, **When** he runs a sudo command, **Then** the command executes without password prompt
3. **Given** coal is logged in, **When** he accesses docker, **Then** he can run containers without sudo
4. **Given** coal is logged in, **When** he opens code-server in browser, **Then** he has access to his home directory and projects

---

### User Story 2 - Violino Accesses Devbox as Secondary User (Priority: P2)

Violino (violinomaestro@gmail.com) is a secondary user with SSH access to the shared devbox. She needs her own isolated user account with her own home directory, shell configuration, and development environment. Per the Tailscale ACL in homelab-iac, her access is restricted to SSH (port 22) only.

**Why this priority**: Supporting the second authorized user is the core feature request. However, the admin account must work first.

**Independent Test**: Violino can SSH into the devbox with her own credentials, has her own home directory, and can use development tools without affecting Cole's environment.

**Acceptance Scenarios**:

1. **Given** the devbox is deployed, **When** Violino connects via SSH using her authorized key, **Then** she is logged into her own user account
2. **Given** Violino is logged in, **When** she creates files in her home directory, **Then** those files are not visible to Cole (standard Unix permissions)
3. **Given** Violino is logged in, **When** she customizes her shell environment, **Then** her customizations do not affect Cole's environment
4. **Given** Violino is logged in, **When** she runs development tools, **Then** she has access to the same toolset as Cole

---

### User Story 3 - User Isolation and Security (Priority: P2)

Both users share the same physical devbox but their environments must be appropriately isolated. Each user has their own home directory, shell configuration, and process space. Shared resources (docker, system packages) are available to both users.

**Why this priority**: Security and isolation are fundamental to multi-user systems and must be implemented alongside the secondary user.

**Independent Test**: Each user's files and processes are isolated by standard Unix permissions; shared resources work for both users.

**Acceptance Scenarios**:

1. **Given** both users have accounts, **When** Cole lists Violino's home directory, **Then** access is denied (standard Unix permissions)
2. **Given** both users are logged in simultaneously, **When** each runs processes, **Then** processes run under their respective UIDs
3. **Given** docker is available, **When** either user runs docker commands, **Then** they can access the shared docker daemon

---

### User Story 4 - Per-User Home Manager Configuration (Priority: P3)

Each user has their own Home Manager configuration defining their personal environment (shell aliases, git config, editor settings). This allows personalization without system-wide changes.

**Why this priority**: Personalization improves user experience but is not essential for basic functionality.

**Independent Test**: Each user can have different shell aliases, git user.name, or editor configurations without conflicts.

**Acceptance Scenarios**:

1. **Given** Cole has custom fish abbreviations, **When** Violino logs in, **Then** she does not see Cole's abbreviations
2. **Given** each user has a git config with their name/email, **When** they commit, **Then** commits are attributed to the correct user
3. **Given** a user modifies their Home Manager config, **When** the system rebuilds, **Then** only that user's environment changes

---

### Edge Cases

- What happens when both users try to access code-server simultaneously?
  - Each user has their own code-server instance on a dedicated port (Cole: 8080, Violino: 8081), so no conflict occurs
- What happens if a user's SSH key is removed from the configuration?
  - They lose access; this is expected and intentional
- What happens if one user fills the disk?
  - Affects all users; consider disk quotas as future enhancement (out of scope for MVP)
- What happens if Violino tries to access services beyond SSH (per Tailscale ACL)?
  - Tailscale blocks the connection at the network level (handled by homelab-iac, not this devbox)

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST support multiple user accounts with separate home directories
- **FR-002**: System MUST allow each user to authenticate via their own SSH public key, injected via environment variables at build time (not hardcoded in repo)
- **FR-003**: System MUST provide user isolation via standard Unix permissions
- **FR-004**: System MUST allow the primary admin user (coal) sudo access without password
- **FR-005**: System MUST provide each user with the same base development toolset (fish, fzf, bat, eza, etc.)
- **FR-006**: System MUST support per-user Home Manager configurations
- **FR-007**: System MUST allow both users to access the shared docker daemon
- **FR-008**: System MUST validate that each user has at least one valid SSH key configured
- **FR-009**: System MUST use usernames that identify each user (e.g., `coal`, `violino`) rather than generic names
- **FR-010**: Secondary user (Violino) MUST NOT have sudo access by default
- **FR-011**: System MUST provide per-user code-server instances on separate ports (Cole: 8080, Violino: 8081)
- **FR-012**: System MUST NOT include real SSH keys in FlakeHub published artifacts; CI publish job must not have key environment variables configured

### Key Entities

- **User Account**: Represents a system user with username, UID, home directory, shell, group memberships, and SSH keys
- **Home Manager Configuration**: Per-user environment settings including shell config, git config, and installed user packages
- **User Groups**: Shared group memberships (docker, etc.) that grant access to system resources

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Both authorized users (Cole, Violino) can SSH into the devbox with their respective credentials
- **SC-002**: Each user has a separate home directory with appropriate Unix permissions (700 or 750)
- **SC-003**: Cole can execute sudo commands; Violino cannot
- **SC-004**: Both users can run docker commands without sudo
- **SC-005**: Home Manager successfully manages both users' environments without conflicts
- **SC-006**: System builds successfully with `nix flake check` including assertions for both users' SSH keys
- **SC-007**: Adding a new user in the future requires only configuration changes, not code restructuring

## Assumptions

- SSH public keys are injected via environment variables (e.g., `SSH_KEY_COAL`, `SSH_KEY_VIOLINO`) at build time; CI publish job must NOT have these secrets to avoid publishing keys to FlakeHub
- If env vars are not set, placeholder keys are used (build succeeds with warning, SSH auth fails gracefully)
- Optional strict mode (`NIX_STRICT_KEYS=true`) causes build to fail if keys are missing
- The Tailscale ACL configuration in homelab-iac handles network-level access control; the devbox trusts SSH connections that reach it
- Both users need the same base toolset; per-user package customization is handled via Home Manager
- code-server runs as per-user instances on dedicated ports (Cole: 8080, Violino: 8081)
- Disk quotas are out of scope for initial implementation

## Dependencies

- Tailscale ACL in homelab-iac defines who can reach the devbox (ColeB1722@github and violinomaestro@gmail.com)
- SSH public key environment variables must be set for deployment builds (via CI deploy secrets or local `.env` file); CI publish job must NOT have these secrets
- Existing Home Manager configuration in home/default.nix will be refactored to support multiple users

## Out of Scope

- Disk quotas or resource limits per user
- User management UI (users are managed declaratively in Nix)
- Dynamic user creation (all users are defined in configuration)
- Per-user docker isolation (both users share the docker daemon)
- LDAP, Active Directory, or other external authentication

## Future Enhancements

- **CodeRabbit CLI**: Add CodeRabbit CLI (`cr`) for local AI-powered code review. Not currently in nixpkgs; requires either a custom Nix derivation or activation script to install via `curl -fsSL https://coderabbit.ai/install.sh | bash`. Lower priority as CodeRabbit GitHub App provides the same functionality for PRs.
