# Feature Specification: Development Tools and Configuration

**Feature Branch**: `005-devtools-config`  
**Created**: 2026-01-18  
**Status**: Draft  
**Input**: User description: "Enrich the foundational implementation with tools and configurations including zellij, fish as the default shell, proper docker setup, opencode, claude code, zed remote server, code server, gh, uv, npm, tree, ripgrep, fzf, bat, lazygit, fd, terraform, eza, 1password, and coderabbit."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Shell Environment Ready on Login (Priority: P1)

As a developer, I want to have a fully configured fish shell with modern CLI tools available immediately upon SSH login, so I can start working productively without manual setup.

**Why this priority**: The shell is the primary interface for all development work. Without a functional shell environment, no other tools can be effectively used.

**Independent Test**: Can be tested by SSHing into the devbox and verifying fish is the default shell with all CLI tools (tree, ripgrep, fzf, bat, fd, eza) accessible from the command line.

**Acceptance Scenarios**:

1. **Given** a user SSHs into the devbox, **When** the session starts, **Then** fish shell is the active shell with proper prompt configuration
2. **Given** a user is in a fish session, **When** they run any installed CLI tool (tree, rg, fzf, bat, fd, eza), **Then** the tool executes without "command not found" errors
3. **Given** a user opens a terminal session, **When** they use fzf-based history search (Ctrl+R), **Then** interactive fuzzy search is available

---

### User Story 2 - Container Development Workflow (Priority: P1)

As a developer, I want Docker properly configured and running, so I can build, run, and manage containers for my development projects.

**Why this priority**: Container-based development is essential for modern software development workflows and testing.

**Independent Test**: Can be tested by running `docker run hello-world` and `docker compose` commands successfully.

**Acceptance Scenarios**:

1. **Given** the devbox is running, **When** a user runs `docker ps`, **Then** the Docker daemon responds without permission errors
2. **Given** a user has a docker-compose.yml file, **When** they run `docker compose up`, **Then** containers start successfully
3. **Given** a user in the developer group, **When** they run Docker commands, **Then** no sudo is required

---

### User Story 3 - AI-Assisted Coding Tools Available (Priority: P2)

As a developer, I want OpenCode and Claude Code CLI tools installed and ready to use, so I can leverage AI assistance for coding tasks.

**Why this priority**: AI coding assistants significantly improve developer productivity but are secondary to having the base development environment working.

**Independent Test**: Can be tested by running `opencode` and `claude` commands and verifying they launch or prompt for configuration.

**Acceptance Scenarios**:

1. **Given** a user is logged in, **When** they run `opencode`, **Then** the OpenCode CLI launches or prompts for initial setup
2. **Given** a user is logged in, **When** they run `claude`, **Then** the Claude Code CLI launches or prompts for authentication
3. **Given** credentials are configured, **When** using AI tools, **Then** they can assist with code generation and analysis

---

### User Story 4 - Remote IDE Access (Priority: P2)

As a developer, I want to connect to the devbox using VS Code (via code-server) or Zed's remote server, so I can develop using a full IDE experience remotely.

**Why this priority**: IDE access is critical for complex development tasks but requires the base system to be functional first.

**Independent Test**: Can be tested by accessing code-server via browser or connecting Zed client to the remote server.

**Acceptance Scenarios**:

1. **Given** code-server is running, **When** a user navigates to the web interface, **Then** VS Code loads in the browser
2. **Given** zed remote server is configured, **When** a Zed client connects, **Then** remote editing session is established
3. **Given** the IDE is connected, **When** editing files, **Then** changes are saved to the devbox filesystem

---

### User Story 5 - Terminal Multiplexer for Persistent Sessions (Priority: P2)

As a developer, I want zellij available for terminal multiplexing, so I can maintain persistent work sessions that survive disconnections.

**Why this priority**: Session persistence is important for long-running tasks and multi-window workflows but is usable after the base shell is configured.

**Independent Test**: Can be tested by running `zellij` and creating multiple panes/tabs that persist after detach/reattach.

**Acceptance Scenarios**:

1. **Given** a user runs `zellij`, **When** the session starts, **Then** zellij launches with default configuration
2. **Given** an active zellij session, **When** the SSH connection drops and reconnects, **Then** the session can be reattached
3. **Given** zellij is running, **When** creating new panes or tabs, **Then** they inherit the fish shell environment

---

### User Story 6 - Version Control and Git Workflow (Priority: P2)

As a developer, I want lazygit and gh CLI available, so I can manage Git repositories and GitHub interactions efficiently.

**Why this priority**: Version control is essential for development but works independently of other tools.

**Independent Test**: Can be tested by running `lazygit` in a git repo and using `gh auth status`.

**Acceptance Scenarios**:

1. **Given** a user is in a git repository, **When** they run `lazygit`, **Then** the TUI interface opens showing repo status
2. **Given** gh CLI is installed, **When** a user runs `gh auth login`, **Then** authentication flow begins
3. **Given** gh is authenticated, **When** running `gh pr list`, **Then** pull requests are displayed

---

### User Story 7 - Package Management Tools (Priority: P2)

As a developer, I want npm and uv (Python) package managers available, so I can manage dependencies for JavaScript and Python projects.

**Why this priority**: Package managers are needed for most development projects and are foundational for language-specific work.

**Independent Test**: Can be tested by running `npm --version` and `uv --version`.

**Acceptance Scenarios**:

1. **Given** a user has a package.json file, **When** they run `npm install`, **Then** dependencies are installed successfully
2. **Given** a user has a Python project, **When** they run `uv pip install`, **Then** Python packages are installed
3. **Given** npm is installed, **When** running `npx` commands, **Then** they execute correctly

---

### User Story 8 - Infrastructure as Code (Priority: P3)

As a developer, I want Terraform installed, so I can manage infrastructure definitions for cloud deployments.

**Why this priority**: IaC is important but more specialized; not all users will need it immediately.

**Independent Test**: Can be tested by running `terraform version` and `terraform init` in a project directory.

**Acceptance Scenarios**:

1. **Given** Terraform is installed, **When** a user runs `terraform version`, **Then** version information is displayed
2. **Given** a Terraform configuration exists, **When** running `terraform init`, **Then** providers are downloaded and initialized

---

### User Story 9 - Secrets Management (Priority: P3)

As a developer, I want 1Password CLI integration available, so I can securely access secrets and credentials during development.

**Why this priority**: Secrets management is security-critical but typically configured after basic tools are working.

**Independent Test**: Can be tested by running `op --version` and attempting `op signin`.

**Acceptance Scenarios**:

1. **Given** 1Password CLI is installed, **When** a user runs `op signin`, **Then** authentication flow begins
2. **Given** 1Password is authenticated, **When** retrieving a secret with `op read`, **Then** the secret value is returned

---

### User Story 10 - Code Review Integration (Priority: P3)

As a developer, I want CodeRabbit configured for automated code review, so I can get AI-powered feedback on pull requests.

**Why this priority**: Automated review is valuable but requires other tools (gh, git) to be functional first.

**Independent Test**: Can be tested by verifying CodeRabbit configuration is present and activates on PR creation.

**Acceptance Scenarios**:

1. **Given** CodeRabbit is configured, **When** a pull request is created, **Then** automated review comments are generated
2. **Given** review comments exist, **When** viewing the PR, **Then** CodeRabbit feedback is visible

---

### Edge Cases

- What happens when Docker daemon fails to start? System should log errors and allow manual restart via systemctl
- How does the system handle tools that require authentication (1Password, gh, AI tools) before first use? Clear prompts should guide users through setup
- What happens when zellij session storage fills up? Old sessions should be cleanable with documented commands
- How does the system behave when network is unavailable for tools requiring internet? Graceful degradation with clear error messages
- What if code-server port conflicts with another service? Configuration should use non-conflicting ports

## Requirements *(mandatory)*

### Functional Requirements

**Shell Environment**
- **FR-001**: System MUST set fish as the default login shell for the developer user
- **FR-002**: System MUST include fish shell completions for all installed CLI tools
- **FR-003**: System MUST provide a functional fish configuration with sensible defaults

**CLI Tools**
- **FR-004**: System MUST install and make available: tree, ripgrep (rg), fzf, bat, fd, eza
- **FR-005**: System MUST configure fzf integration with fish shell for history and file search
- **FR-006**: System MUST configure eza as an enhanced ls alternative

**Container Runtime**
- **FR-007**: System MUST install Docker with the Docker daemon enabled and running
- **FR-008**: System MUST configure the developer user to run Docker without sudo (via docker group membership)
- **FR-009**: System MUST include Docker Compose for multi-container workflows

**AI Coding Tools**
- **FR-010**: System MUST install OpenCode CLI tool
- **FR-011**: System MUST install Claude Code CLI tool
- **FR-012**: AI tools MUST be accessible from the command line after installation

**Remote Development**
- **FR-013**: System MUST install and enable code-server for browser-based VS Code
- **FR-014**: System MUST install Zed editor's remote server component
- **FR-015**: Remote IDE services MUST be accessible via Tailscale network

**Terminal Multiplexer**
- **FR-016**: System MUST install zellij terminal multiplexer
- **FR-017**: Zellij MUST use fish as the default shell for new panes

**Version Control**
- **FR-018**: System MUST install lazygit for TUI-based git operations
- **FR-019**: System MUST install GitHub CLI (gh) for GitHub integration

**Package Managers**
- **FR-020**: System MUST install npm for JavaScript/Node.js package management
- **FR-021**: System MUST install uv for Python package and environment management

**Infrastructure Tools**
- **FR-022**: System MUST install Terraform for infrastructure as code

**Secrets Management**
- **FR-023**: System MUST install 1Password CLI (op)

**Code Review**
- **FR-024**: System MUST include CodeRabbit configuration file template for repository integration

### Key Entities

- **Developer User**: The primary user account that will have access to all development tools, member of docker group
- **Development Tools**: CLI utilities and applications installed system-wide or via Home Manager
- **Services**: Long-running processes (Docker daemon, code-server) managed by systemd
- **Shell Configuration**: Fish shell settings, aliases, and integrations stored in user's home directory

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Developer can start productive work within 5 minutes of first SSH login (all tools available, no manual installation required)
- **SC-002**: All 20+ specified tools are accessible via command line without additional setup steps
- **SC-003**: Docker containers can be built and run without permission errors or sudo requirements
- **SC-004**: Remote IDE sessions (code-server, Zed) connect successfully within 30 seconds
- **SC-005**: Terminal sessions persist across SSH disconnections using zellij (100% session recovery)
- **SC-006**: Shell startup time remains under 500ms with all tools and integrations loaded
  - *Mitigation*: If exceeded, lazy-load fzf keybindings or reduce shellInit complexity
- **SC-007**: System passes all NixOS assertions and builds without errors
- **SC-008**: Configuration remains portable between bare-metal and WSL deployments

## Assumptions

- The base NixOS devbox configuration from feature 001 is already in place
- Tailscale networking is configured for remote access to services
- Users will configure authentication for services (1Password, gh, AI tools) on first use
- CodeRabbit is configured at the repository level via .coderabbit.yaml, not as a system service
- Fish shell plugins and configuration will be managed via Home Manager's programs.fish module
- All tools will be installed via Nix packages; OpenCode and Claude Code are both available in nixpkgs (claude-code requires allowUnfree)
