# Feature Specification: Extended Development Tools

**Feature Branch**: `008-extended-devtools`  
**Created**: 2026-01-25  
**Status**: Draft  
**Input**: User description: "Add additional development tools: goose, podman, ttyd, cargo, yazi, syncthing, aerospace (nix-darwin), and hyprland (nixos headed)"

## Current State Analysis

### Already Implemented
- **fd**: ✅ Installed in `home/modules/cli.nix`
- **ripgrep**: ✅ Installed in `home/modules/cli.nix`
- **Tailscale**: ✅ Basic service in `nixos/tailscale.nix` (but not Tailscale SSH with automated auth)

### Not Yet Implemented
- **goose** - AI agent for terminal (Block's open-source CLI)
- **podman** - Rootless container runtime (Docker alternative)
- **ttyd** - Terminal sharing over web browser
- **cargo** - Rust toolchain/package manager
- **yazi** - Terminal file manager
- **syncthing** - Continuous file synchronization
- **aerospace** - Tiling window manager for macOS (nix-darwin only)
- **hyprland** - Wayland compositor for Linux (NixOS headed only)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Core CLI Tools Installation (Priority: P1)

As a developer, I want additional CLI tools (goose, cargo, yazi) available in my terminal so I can enhance my development workflow with AI assistance, Rust development, and better file navigation.

**Why this priority**: These are user-space tools that work across all platforms and have no complex service dependencies. They provide immediate value with minimal configuration.

**Independent Test**: After rebuild, user can run `goose --help`, `cargo --version`, and `yazi` commands successfully.

**Acceptance Scenarios**:

1. **Given** a freshly rebuilt system, **When** I run `goose --help`, **Then** the AI agent CLI shows available commands
2. **Given** a freshly rebuilt system, **When** I run `cargo --version`, **Then** Rust toolchain version is displayed
3. **Given** a freshly rebuilt system, **When** I run `yazi`, **Then** the terminal file manager opens in the current directory

---

### User Story 2 - Container Runtime with Podman (Priority: P2)

As a developer, I want to run containers using Podman so I can have a rootless, daemonless container experience as an alternative to Docker.

**Why this priority**: Container workflows are essential for development. Podman provides Docker-compatible CLI without requiring a daemon, improving security and resource usage.

**Independent Test**: User can pull and run a container image using `podman run hello-world`.

**Acceptance Scenarios**:

1. **Given** Podman is installed, **When** I run `podman run hello-world`, **Then** the container executes and displays the hello message
2. **Given** Podman is installed, **When** I run `podman ps`, **Then** I see container status (even if empty)
3. **Given** a Dockerfile exists, **When** I run `podman build .`, **Then** the image builds successfully

---

### User Story 3 - Terminal Sharing with ttyd (Priority: P3)

As a developer, I want to share my terminal session via web browser so I can collaborate or demonstrate work to others on my tailnet.

**Why this priority**: Useful for collaboration and demos, but not essential for daily development. Depends on Tailscale for secure access.

**Independent Test**: User starts ttyd service and accesses terminal via browser at `http://hostname:port`.

**Acceptance Scenarios**:

1. **Given** ttyd is installed, **When** I run `ttyd bash`, **Then** a web server starts serving my terminal
2. **Given** ttyd is running, **When** I open the URL in a browser, **Then** I see an interactive terminal session
3. **Given** ttyd is accessed via Tailscale, **When** I type commands, **Then** they execute in real-time

---

### User Story 4 - File Synchronization with Syncthing (Priority: P3)

As a developer, I want Syncthing running so I can continuously sync files between my development machines without cloud services.

**Why this priority**: Useful for multi-machine workflows but requires configuration of sync folders. Lower priority as it's supplementary to primary dev tools.

**Independent Test**: Syncthing web UI is accessible and shows device status.

**Acceptance Scenarios**:

1. **Given** Syncthing service is enabled, **When** I access the web UI, **Then** I see the Syncthing dashboard
2. **Given** two machines with Syncthing, **When** I add a sync folder, **Then** files synchronize between machines
3. **Given** Syncthing is running, **When** I check service status, **Then** it shows as active

---

### User Story 5 - macOS Window Management with Aerospace (Priority: P3)

As a macOS user, I want the Aerospace tiling window manager so I can efficiently manage windows using keyboard shortcuts.

**Why this priority**: Platform-specific (nix-darwin only). Enhances productivity but only applicable to macOS users.

**Independent Test**: After darwin-rebuild, Aerospace launches and responds to configured keybindings.

**Acceptance Scenarios**:

1. **Given** Aerospace is installed on macOS, **When** I use the configured hotkey, **Then** windows tile as expected
2. **Given** Aerospace is running, **When** I open multiple windows, **Then** I can navigate between them via keyboard
3. **Given** nix-darwin configuration, **When** I rebuild, **Then** Aerospace starts automatically

---

### User Story 6 - Linux Desktop with Hyprland (Priority: P4)

As a NixOS user with a display, I want Hyprland compositor so I can have a modern Wayland desktop experience with tiling capabilities.

**Why this priority**: Only applicable to headed NixOS installations (not WSL, not headless servers). Lowest priority as current focus is headless-first.

**Independent Test**: NixOS boots into Hyprland session with working display.

**Acceptance Scenarios**:

1. **Given** Hyprland is configured on headed NixOS, **When** system boots, **Then** Hyprland session is available at login
2. **Given** Hyprland is running, **When** I use configured keybindings, **Then** windows tile and move as expected
3. **Given** Hyprland configuration, **When** I open a terminal, **Then** it renders correctly in Wayland

---

### Edge Cases

- What happens when Podman and Docker are both installed? (Potential socket conflicts)
- What happens when Syncthing sync conflicts occur?
- How does Aerospace behave on multi-monitor setups?
- What happens when Hyprland is included in a headless configuration? (Should be skipped gracefully)
- What happens when goose API keys are not configured? (Graceful degradation)

## Requirements *(mandatory)*

### Functional Requirements

#### Core CLI Tools
- **FR-001**: System MUST install goose (Block's AI agent) in user environment
- **FR-002**: System MUST install Rust toolchain (cargo, rustc) in user environment
- **FR-003**: System MUST install yazi terminal file manager in user environment

#### Container Runtime
- **FR-004**: System MUST install Podman with rootless configuration
- **FR-005**: System MUST configure Podman to be Docker CLI-compatible where possible
- **FR-006**: System MUST NOT conflict with existing Docker installation (WSL uses Docker Desktop)
- **FR-007**: Podman installation provides rootless container runtime for development use

#### Terminal Sharing
- **FR-008**: System MUST install ttyd for web-based terminal sharing
- **FR-009**: ttyd MUST be accessible only via Tailscale network (not public internet)

#### File Synchronization
- **FR-010**: System MUST install and enable Syncthing service
- **FR-011**: Syncthing web UI MUST be accessible only via Tailscale network
- **FR-012**: Syncthing MUST run as a specific user with user-owned data directories (not as root or with shared system state)

#### Platform-Specific: macOS
- **FR-013**: nix-darwin configuration MUST include Aerospace window manager
- **FR-014**: Aerospace MUST be configurable via nix-darwin options

#### Platform-Specific: NixOS Headed
- **FR-015**: Headed NixOS configurations MUST support Hyprland compositor as an option
- **FR-016**: Hyprland MUST NOT be included in headless/WSL configurations
- **FR-017**: Hyprland configuration MUST be modular (opt-in, not default)

### Key Entities

- **DevTool**: A development tool installed via Nix (package name, platform compatibility, configuration options)
- **Service**: A background service (Syncthing, ttyd) with network access requirements
- **Platform**: Target platform (NixOS bare-metal, NixOS WSL, nix-darwin) determining which tools apply

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All P1 tools (goose, cargo, yazi) are available in PATH within 5 seconds of shell startup
- **SC-002**: `podman run hello-world` completes successfully on first attempt after installation
- **SC-003**: ttyd web terminal loads in browser within 2 seconds of navigation
- **SC-004**: Syncthing detects peer devices within 60 seconds on same tailnet
- **SC-005**: Aerospace responds to keybindings within 100ms on macOS
- **SC-006**: Hyprland boots to usable desktop within 10 seconds on headed NixOS
- **SC-007**: No configuration errors during `nixos-rebuild` or `darwin-rebuild` for any platform
- **SC-008**: Tools gracefully degrade (with clear error messages) when dependencies are missing

## Assumptions

- Tailscale is already configured and authenticated (existing `devbox.tailscale.enable`)
- Users on WSL will continue using Docker Desktop (no Podman needed on WSL)
- Headed NixOS installations are a future use case (not current priority)
- nix-darwin support is planned but not yet implemented (see `darwin/README.md`)

