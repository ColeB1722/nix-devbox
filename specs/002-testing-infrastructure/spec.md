# Feature Specification: Testing Infrastructure

**Feature Branch**: `002-testing-infrastructure`  
**Created**: 2026-01-17  
**Status**: Draft  
**Input**: User description: "Testing and pre-commit infrastructure for NixOS flake validation"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Pre-commit Code Quality Checks (Priority: P1)

As a developer, I want automatic code quality checks to run before I commit changes so that I catch formatting issues, linting errors, and common mistakes before they enter the repository.

**Why this priority**: Pre-commit hooks provide immediate feedback during development, catching issues at the earliest possible point. This is the foundation for code quality and can be used independently of any CI system.

**Independent Test**: Can be fully tested by making a change with formatting issues and verifying the commit is blocked with clear error messages, or that the code is auto-formatted.

**Acceptance Scenarios**:

1. **Given** I have uncommitted Nix files with formatting issues, **When** I attempt to commit, **Then** the pre-commit hook formats them automatically or warns me about issues.
2. **Given** I have Nix code with linting violations (antipatterns), **When** I attempt to commit, **Then** the hook reports the specific issues and their locations.
3. **Given** I have Nix code with unused variables or dead code, **When** I attempt to commit, **Then** the hook identifies the unused elements.
4. **Given** I enter the development shell, **When** I check git hooks, **Then** the pre-commit hooks are automatically installed.

---

### User Story 2 - Local Flake Validation (Priority: P2)

As a developer, I want to validate that my flake structure and Nix expressions are correct locally so that I can catch syntax and evaluation errors before pushing to CI.

**Why this priority**: Local validation provides faster feedback than CI and doesn't require network access. While pre-commit catches formatting/linting, this catches deeper structural issues.

**Independent Test**: Can be fully tested by running a validation command and verifying it reports success or specific errors for the flake configuration.

**Acceptance Scenarios**:

1. **Given** a valid flake configuration, **When** I run the validation command, **Then** it reports success.
2. **Given** a flake with syntax errors, **When** I run the validation command, **Then** it reports the specific error and location.
3. **Given** a flake with missing inputs or invalid references, **When** I run the validation command, **Then** it identifies the missing dependencies.

---

### User Story 3 - CI Build Verification (Priority: P3)

As a developer, I want automated CI to verify that the NixOS configuration builds successfully on every push so that I have confidence the configuration will work on deployment.

**Why this priority**: CI provides the ultimate verification that the configuration builds on a real Linux system. Since development may occur on macOS, this ensures Linux-specific issues are caught.

**Independent Test**: Can be fully tested by pushing a branch and verifying the CI workflow runs and reports build status.

**Acceptance Scenarios**:

1. **Given** I push commits to the repository, **When** CI runs, **Then** it verifies the flake structure is valid.
2. **Given** I push commits to the repository, **When** CI runs, **Then** it builds the NixOS configuration to verify it evaluates correctly.
3. **Given** the CI build fails, **When** I view the workflow results, **Then** I see clear error messages indicating what went wrong.
4. **Given** the CI build succeeds, **When** I view the workflow results, **Then** I see confirmation that all checks passed.

---

### Edge Cases

- What happens when pre-commit hooks fail but the developer wants to commit anyway? There should be a documented bypass mechanism for emergencies (e.g., `--no-verify`).
- How does the system handle partial Nix installations on developer machines? The development shell should provide all required tools.
- What happens when CI runs on a fork or from a contributor without repository secrets? CI should still run basic validation without requiring secrets.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Repository MUST include pre-commit hook configuration that automatically runs on commit.
- **FR-002**: Pre-commit hooks MUST include Nix code formatting validation.
- **FR-003**: Pre-commit hooks MUST include Nix linting for common antipatterns.
- **FR-004**: Pre-commit hooks MUST detect unused variables and dead code in Nix files.
- **FR-005**: Development shell MUST automatically install git hooks when entered.
- **FR-006**: Repository MUST provide a command to run all checks manually without committing.
- **FR-007**: CI workflow MUST validate flake structure on every push and pull request.
- **FR-008**: CI workflow MUST build the NixOS configuration to verify it evaluates correctly.
- **FR-009**: CI MUST run on Linux to verify the NixOS-specific configuration.
- **FR-010**: All validation tools MUST be pinned via the flake for reproducibility.

### Key Entities

- **Git Hooks Configuration**: Pre-commit hook definitions specifying which checks run and their configuration.
- **Development Shell**: Nix shell environment that provides all development tools and installs hooks.
- **CI Workflow**: Automated pipeline definition that runs on repository events.
- **Check Results**: Output from validation tools indicating pass/fail status and specific issues.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Pre-commit hooks catch 100% of formatting violations before they enter the repository.
- **SC-002**: Developer can run all validation checks with a single command in under 30 seconds for the current codebase size.
- **SC-003**: CI provides build status feedback within 10 minutes of push.
- **SC-004**: New contributors can set up the development environment and have hooks installed automatically on first shell entry.
- **SC-005**: All Nix code in the repository passes formatting, linting, and dead code checks.
- **SC-006**: CI runs successfully on both direct pushes and pull requests from forks.

## Assumptions

- GitHub Actions is the CI platform (free for public repositories, available for private).
- The `nixfmt` formatter will be used as it's becoming the nixpkgs standard.
- Pre-commit is the preferred hook timing (run on every commit for immediate feedback).
- The `git-hooks.nix` (cachix) integration will be used as it's the standard for Nix projects.
- Tools used: `nixfmt` (formatter), `statix` (linter), `deadnix` (dead code detection).
- Development occurs on macOS but deployment targets NixOS (x86_64-linux).
