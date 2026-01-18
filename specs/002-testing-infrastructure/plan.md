# Implementation Plan: Testing Infrastructure

**Branch**: `002-testing-infrastructure` | **Date**: 2026-01-17 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/002-testing-infrastructure/spec.md`

## Summary

Implement a comprehensive testing infrastructure for the nix-devbox flake that provides:
1. Pre-commit hooks via git-hooks.nix for automated code quality checks (formatting, linting, dead code detection)
2. Local flake validation commands for manual testing
3. GitHub Actions CI workflow for automated build verification on Linux

## Technical Context

**Language/Version**: Nix (flakes format, NixOS 24.05+)
**Primary Dependencies**: git-hooks.nix (cachix), nixfmt, statix, deadnix
**Storage**: N/A (configuration files only)
**Testing**: `nix flake check` for sandboxed validation, `pre-commit run` for hook execution
**Target Platform**: Development on macOS/Linux, CI on Linux (ubuntu-latest)
**Project Type**: Infrastructure extension to existing NixOS flake
**Performance Goals**: Pre-commit hooks complete in under 30 seconds for current codebase
**Constraints**: Must work on macOS for development, must verify NixOS builds on Linux CI
**Scale/Scope**: Single repository, personal development workflow

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Evidence |
|-----------|--------|----------|
| I. Declarative Configuration | ✅ PASS | All hooks and CI defined in Nix flake; no imperative setup |
| II. Headless-First Design | ✅ PASS | All tools are CLI-based; no GUI components |
| III. Security by Default | ✅ PASS | No secrets required; CI works on forks without secrets |
| IV. Modular and Reusable | ✅ PASS | Hooks integrated into existing flake; reusable devShell |
| V. Documentation as Code | ✅ PASS | Configuration is self-documenting; quickstart provided |

**Gate Result**: PASS - All principles satisfied by design.

## Project Structure

### Documentation (this feature)

```text
specs/002-testing-infrastructure/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output (configuration structure)
├── quickstart.md        # Phase 1 output (usage guide)
└── contracts/           # Phase 1 output (hook interfaces)
```

### Source Code (repository root)

```text
flake.nix                # Extended with git-hooks.nix, checks, devShell
flake.lock               # Updated with new inputs

.github/
└── workflows/
    └── ci.yml           # GitHub Actions workflow

# Existing structure (unchanged)
hosts/
modules/
home/
```

**Structure Decision**: Extend the existing flake.nix with new inputs and outputs. Add GitHub Actions workflow in standard location. No new Nix modules required - all configuration integrates into the flake outputs.

## Complexity Tracking

No violations to justify. Design aligns with all constitutional principles.
