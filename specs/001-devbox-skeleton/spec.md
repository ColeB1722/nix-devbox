# Feature Specification: Devbox Skeleton

**Feature Branch**: `001-devbox-skeleton`  
**Created**: 2026-01-17  
**Status**: Draft  
**Input**: User description: "I want to put inplace the skeleton of the dev machine as a foundation to build off of later"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Initial Deployment (Priority: P1)

As a developer, I want to deploy a minimal but functional NixOS configuration to a fresh machine so that I have a working foundation for remote development.

**Why this priority**: Without a deployable base configuration, no other features can be added. This is the absolute minimum viable product.

**Independent Test**: Can be tested by deploying to a fresh VM or bare metal machine and verifying SSH access works via Tailscale.

**Acceptance Scenarios**:

1. **Given** a fresh machine with NixOS installer, **When** I apply the skeleton configuration, **Then** the system boots successfully with SSH and Tailscale services running.
2. **Given** the deployed skeleton, **When** I connect via Tailscale IP over SSH with my key, **Then** I am authenticated and dropped into a shell.
3. **Given** the deployed skeleton, **When** I attempt to SSH with a password, **Then** the connection is rejected.

---

### User Story 2 - Modular Structure Setup (Priority: P2)

As a developer, I want the configuration organized into logical modules so that I can easily add, remove, or modify individual components without affecting the entire system.

**Why this priority**: Modularity enables all future development. Without this structure, adding features becomes increasingly difficult and error-prone.

**Independent Test**: Can be tested by examining the file structure and verifying that each module can be enabled/disabled independently without breaking the build.

**Acceptance Scenarios**:

1. **Given** the skeleton repository, **When** I examine the file structure, **Then** I find separate modules for core system, networking, and user configuration.
2. **Given** a module (e.g., shell configuration), **When** I disable it in the configuration, **Then** the system still builds and deploys successfully.
3. **Given** a new module I want to add, **When** I create it following the established pattern, **Then** it integrates without modifying existing modules.

---

### User Story 3 - Secure Remote Access (Priority: P3)

As a developer, I want secure-by-default network configuration so that I can access my devbox remotely without exposing it to unnecessary risk.

**Why this priority**: Security is a constitutional requirement. While P1 includes basic SSH/Tailscale, this story ensures firewall rules and hardening are properly configured.

**Independent Test**: Can be tested by running security scans and verifying only expected ports are accessible, and only via Tailscale.

**Acceptance Scenarios**:

1. **Given** the deployed skeleton, **When** I scan for open ports from the public internet, **Then** no ports are accessible (all traffic goes through Tailscale).
2. **Given** the deployed skeleton, **When** I check the firewall configuration, **Then** it defaults to deny-all with explicit allowlist for required services.
3. **Given** the deployed skeleton, **When** I attempt root SSH login, **Then** it is denied.

---

### Edge Cases

- What happens when Tailscale is unavailable (e.g., network issues)? System should still be accessible via local console or alternative recovery method.
- How does the system handle a failed configuration deployment? NixOS rollback via bootloader should allow recovery to previous generation.
- What happens if the SSH key is lost? Recovery requires physical console access or pre-configured emergency access method.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST boot into a functional NixOS environment with no manual post-install steps required.
- **FR-002**: System MUST run Tailscale service on boot. Initial tailnet authentication requires a one-time manual `tailscale up` command; automated auth key provisioning is deferred to a future secret management feature.
- **FR-003**: System MUST run SSH service accessible only via key-based authentication.
- **FR-004**: System MUST deny password-based SSH authentication.
- **FR-005**: System MUST deny root SSH login.
- **FR-006**: System MUST configure firewall to default-deny with explicit allowlist.
- **FR-007**: Configuration MUST be structured as composable Nix modules with explicit dependencies.
- **FR-008**: System MUST include a minimal shell environment suitable for further configuration (editor, git, basic utilities).
- **FR-009**: Configuration MUST be fully reproducible from repository contents alone.
- **FR-010**: System MUST support rollback to previous configuration generations.

### Key Entities

- **Host Configuration**: The machine-specific settings (hostname, hardware configuration, network interfaces) that differ per deployment target.
- **Shared Modules**: Reusable configuration components (shell, security hardening, common packages) that apply across machines.
- **User Profile**: Per-user settings managed via Home Manager or equivalent, including dotfiles and user-specific packages.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A fresh machine can be configured from repository contents in under 30 minutes (excluding download time).
- **SC-002**: System passes all acceptance scenarios for User Stories 1-3.
- **SC-003**: Configuration can be modified and redeployed with zero downtime via `nixos-rebuild switch`.
- **SC-004**: At least 3 distinct modules exist that can be independently enabled/disabled.
- **SC-005**: Security scan shows zero unexpected open ports from public internet.
- **SC-006**: Future features can be added by creating new modules without modifying existing skeleton code.

## Assumptions

- User has an existing Tailscale account and auth key available for initial setup.
- Target machine supports NixOS installation (x86_64 or aarch64 architecture).
- User has at least one SSH public key ready for initial authentication.
- User has basic familiarity with Nix expressions and NixOS configuration.
