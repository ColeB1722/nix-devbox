# Data Model: Multi-Platform Development Environment

**Feature Branch**: `009-devcontainer-orchestrator`  
**Date**: 2025-01-25  
**Status**: Complete

## Overview

This document defines the core entities, their attributes, relationships, and state transitions for the multi-platform development environment.

## Entity Diagram

```
┌─────────────────┐         ┌─────────────────┐
│      User       │────────▶│  OrchestratorHost│
│                 │  SSH    │                 │
└────────┬────────┘         └────────┬────────┘
         │                           │
         │ owns (0..5)               │ manages (0..7)
         ▼                           ▼
┌─────────────────┐         ┌─────────────────┐
│  DevContainer   │◀────────│ ContainerImage  │
│                 │  uses   │                 │
└────────┬────────┘         └─────────────────┘
         │
         │ authenticates with
         ▼
┌─────────────────┐         ┌─────────────────┐
│ TailscaleAuthKey│◀────────│  SecretsManager │
│                 │  stores │   (1Password)   │
└─────────────────┘         └─────────────────┘

┌─────────────────┐         ┌─────────────────┐
│ macOSWorkstation│         │ HeadfulDesktop  │
│  (nix-darwin)   │         │    (NixOS)      │
└─────────────────┘         └─────────────────┘
```

## Entities

### User

A person with SSH key access to the orchestrator who can request and manage dev containers.

| Attribute | Type | Constraints | Description |
|-----------|------|-------------|-------------|
| `name` | string | Required, unique | Unix username (e.g., `coal`, `violino`) |
| `uid` | integer | Required, unique, >= 1000 | Unix user ID |
| `email` | string | Required | User email for notifications |
| `sshKeys` | list[string] | Required, min 1 | SSH public keys for orchestrator access |
| `isAdmin` | boolean | Required | Whether user has admin privileges |
| `containerLimit` | integer | Default: 5 | Max containers this user can create |

**Source**: Defined in `lib/users.nix`

**Relationships**:
- Owns 0..N DevContainers (max `containerLimit`)
- Has 1 TailscaleAuthKey in SecretsManager

---

### DevContainer

An isolated container with full development tooling and Tailscale-based remote access.

| Attribute | Type | Constraints | Description |
|-----------|------|-------------|-------------|
| `name` | string | Required, unique globally | User-chosen identifier |
| `owner` | User.name | Required, FK | User who owns this container |
| `state` | enum | Required | Current lifecycle state |
| `createdAt` | datetime | Required | Creation timestamp |
| `lastActivityAt` | datetime | Required | Last user activity timestamp |
| `cpuLimit` | integer | Default: 2 | CPU cores allocated |
| `memoryLimit` | string | Default: "4G" | Memory limit |
| `volumeName` | string | Required | Podman volume for persistent data |
| `tailscaleHostname` | string | Derived | Tailscale network hostname |
| `tailscaleIP` | string | Runtime | Tailscale IP address (when running) |

**Validation Rules**:
- `name`: alphanumeric + hyphens, 3-63 chars, starts with letter
- `name`: unique across all users on the orchestrator
- `owner`: must exist in User table
- `cpuLimit * running_containers <= host_cpu_threads`
- `memoryLimit * running_containers <= host_memory`

**Derived Fields**:
- `tailscaleHostname` = `{name}` (container name becomes Tailscale hostname)

**Source**: Managed by `devbox-ctl`, stored in `~/.local/share/devbox/containers.json`

**Relationships**:
- Owned by 1 User
- Uses 1 ContainerImage
- Authenticates with 1 TailscaleAuthKey

---

### DevContainer State Machine

```
                    ┌──────────────────────────────────────┐
                    │                                      │
                    ▼                                      │
┌─────────┐    ┌─────────┐    ┌─────────┐    ┌──────────┐ │
│ Creating│───▶│ Running │───▶│ Stopped │───▶│ Destroyed│ │
└─────────┘    └────┬────┘    └────┬────┘    └──────────┘ │
                    │              │                       │
                    │              │ start                 │
                    │              ▼                       │
                    │         ┌─────────┐                  │
                    └────────▶│ Running │──────────────────┘
                      stop    └─────────┘       destroy
```

| State | Description | Transitions |
|-------|-------------|-------------|
| `creating` | Container being provisioned | → `running` (success), → `destroyed` (failure) |
| `running` | Container active, Tailscale connected | → `stopped` (manual/auto), → `destroyed` |
| `stopped` | Container paused, preserves state | → `running` (start), → `destroyed` |
| `destroyed` | Container removed, terminal state | None (removed from tracking) |

**Automatic Transitions**:
- `running` → `stopped`: After 7 days of no activity
- `stopped` → `destroyed`: After 14 days in stopped state

---

### ContainerImage

The dockertools-built OCI image containing development tools.

| Attribute | Type | Constraints | Description |
|-----------|------|-------------|-------------|
| `name` | string | Fixed: "devcontainer" | Image name |
| `tag` | string | Required | Version tag (e.g., "latest", "v1.0.0") |
| `digest` | string | Required | SHA256 digest for reproducibility |
| `builtAt` | datetime | Required | Build timestamp |
| `nixHash` | string | Required | Nix store path hash |

**Contents**:
- Base: bash, coreutils, findutils, gnugrep, gnused
- CLI tools: ripgrep, fd, bat, eza, fzf, jq, yazi
- Dev tools: git, gh, neovim, zellij, direnv
- Languages: nodejs, bun, python3, uv, rustc, cargo
- AI tools: goose-cli, aider (if available)
- Remote access: tailscale, code-server, zed-editor
- Init: custom entrypoint script for Tailscale setup

**Source**: Built from `containers/devcontainer/default.nix`

---

### TailscaleAuthKey

A per-user credential that allows a container to join the tailnet with specific tags.

| Attribute | Type | Constraints | Description |
|-----------|------|-------------|-------------|
| `itemName` | string | Derived | 1Password item name: `{username}-tailscale-authkey` |
| `reference` | string | Derived | Full 1Password reference |
| `owner` | User.name | Required, FK | User this key belongs to |
| `tags` | list[string] | Derived | `["tag:devcontainer", "tag:{username}-container"]` |
| `ephemeral` | boolean | Fixed: true | Devices auto-removed when container stops |
| `reusable` | boolean | Fixed: true | Same key used for multiple containers |

**Naming Conventions (defined by library):**

| Component | Convention | Example |
|-----------|------------|---------|
| Item name | `{username}-tailscale-authkey` | `coal-tailscale-authkey` |
| Field | `password` | `tskey-auth-xxxx...` |
| Reference | `op://{vault}/{username}-tailscale-authkey/password` | `op://DevBox/coal-tailscale-authkey/password` |
| Tags | `tag:devcontainer`, `tag:{username}-container` | `tag:devcontainer`, `tag:coal-container` |

**Security**:
- Raw key value NEVER stored on disk or in Nix store
- Retrieved at container creation time only via `op read`
- Passed via environment variable to container (not logged)
- Service Account has read-only access to vault

**Source**: Consumer creates in their 1Password vault (name configurable in `users.nix`)

---

### ServiceAccount

The 1Password Service Account used by the orchestrator to retrieve secrets.

| Attribute | Type | Constraints | Description |
|-----------|------|-------------|-------------|
| `token` | string | Required, secret | `OP_SERVICE_ACCOUNT_TOKEN` value |
| `vaultAccess` | list[string] | Required | Vaults the account can read (e.g., `["DevBox"]`) |
| `rateLimit` | integer | Platform-dependent | 1000/hr (Teams) or 10000/hr (Business) |

**Characteristics**:
- System-wide credential, NOT tied to any individual user
- One token serves all secret retrieval on the orchestrator
- Created by consumer in 1Password web console or CLI
- Token stored securely outside Nix (systemd credential, agenix, /run/secrets)

**Source**: Consumer creates and manages; token provided via environment variable

---

### ContainersConfig

Configuration for the container orchestrator, defined in consumer's `users.nix`.

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `opVault` | string | `"DevBox"` | 1Password vault name containing auth keys |
| `maxPerUser` | integer | 5 | Maximum containers per user |
| `maxGlobal` | integer | 7 | Maximum containers on orchestrator |
| `defaultCpu` | integer | 2 | Default CPU cores per container |
| `defaultMemory` | string | `"4G"` | Default RAM per container |
| `idleStopDays` | integer | 7 | Auto-stop after N days idle |
| `stoppedDestroyDays` | integer | 14 | Auto-destroy after N days stopped |

**Source**: Defined in `users.nix` under `containers` attribute, validated by `lib/schema.nix`

---

### OrchestratorHost

The NixOS server that manages dev containers.

| Attribute | Type | Constraints | Description |
|-----------|------|-------------|-------------|
| `hostname` | string | Required | System hostname |
| `platform` | enum | Required | `bare-metal` or `wsl2` |
| `cpuThreads` | integer | Required | Available CPU threads |
| `memoryGB` | integer | Required | Available RAM in GB |
| `maxContainers` | integer | Default: 7 | Global container limit |
| `tailscaleIP` | string | Required | Tailscale IP for SSH access |

**Derived Limits** (for 32GB RAM, 32 threads):
- `maxContainers` = floor((memoryGB - 4) / 4) = 7
- Reserved: 4GB RAM, 4 threads for host OS

**Source**: Defined in `hosts/devbox/default.nix` or `hosts/devbox-wsl/default.nix`

---

### macOSWorkstation

A local development environment on macOS using nix-darwin.

| Attribute | Type | Constraints | Description |
|-----------|------|-------------|-------------|
| `hostname` | string | Required | System hostname |
| `username` | string | Required | Primary user |
| `architecture` | enum | Required | `aarch64-darwin` or `x86_64-darwin` |
| `aerospaceEnabled` | boolean | Default: true | Aerospace tiling enabled |

**Source**: Defined in `darwinConfigurations` flake output

---

### HeadfulDesktop

A local development environment on NixOS with Hyprland GUI.

| Attribute | Type | Constraints | Description |
|-----------|------|-------------|-------------|
| `hostname` | string | Required | System hostname |
| `username` | string | Required | Primary user |
| `gpuVendor` | enum | Required | `nvidia`, `amd`, or `intel` |
| `hyprlandEnabled` | boolean | Default: true | Hyprland compositor enabled |

**Constraint**: Bare-metal only (no WSL2, no VM without GPU passthrough)

**Source**: Defined in `hosts/devbox-desktop/default.nix`

---

## Data Storage

### Container Registry (Orchestrator)

Location: `~/.local/share/devbox/containers.json`

```json
{
  "version": 1,
  "containers": [
    {
      "name": "my-project",
      "owner": "coal",
      "state": "running",
      "createdAt": "2025-01-25T10:00:00Z",
      "lastActivityAt": "2025-01-25T14:30:00Z",
      "cpuLimit": 2,
      "memoryLimit": "4G",
      "volumeName": "my-project-data",
      "tailscaleHostname": "my-project",
      "tailscaleIP": "100.64.1.50"
    }
  ]
}
```

### Activity Tracking

Container activity detected via:
- SSH connections (Tailscale logs)
- code-server WebSocket activity
- Process activity inside container (optional)

Updated by cleanup timer, checked daily.

---

## Validation Summary

| Entity | Uniqueness | Foreign Keys | Business Rules |
|--------|------------|--------------|----------------|
| User | name, uid | - | containerLimit >= 0 |
| DevContainer | name (global) | owner → User | name format, limits |
| TailscaleAuthKey | reference | owner → User | 1Password format |
| OrchestratorHost | hostname | - | maxContainers based on resources |

---

## Index

For efficient lookups in `containers.json`:

- By name: O(n) scan, could add hash index if > 100 containers
- By owner: O(n) scan, filter in CLI
- By state: O(n) scan, filter in CLI

Given max 7 containers, linear scan is acceptable.