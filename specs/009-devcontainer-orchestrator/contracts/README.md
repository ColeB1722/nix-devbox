# CLI Contract: devbox-ctl

**Feature Branch**: `009-devcontainer-orchestrator`  
**Date**: 2025-01-25  
**Status**: Complete

## Overview

`devbox-ctl` is the command-line interface for managing dev containers on the orchestrator host. It provides user-facing commands for container lifecycle management with built-in validation, limits enforcement, and 1Password secrets integration.

## Installation

The `devbox-ctl` tool is installed as part of the orchestrator NixOS configuration and available in `$PATH` for all users.

## Commands

### devbox-ctl create

Create a new dev container.

```
devbox-ctl create <name> [options]
```

**Arguments**:

| Argument | Required | Description |
|----------|----------|-------------|
| `name` | Yes | Container name (alphanumeric + hyphens, 3-63 chars) |

**Options**:

| Option | Default | Description |
|--------|---------|-------------|
| `--cpu` | 2 | CPU cores to allocate |
| `--memory` | 4G | Memory limit (e.g., 2G, 4G, 8G) |
| `--no-start` | false | Create but don't start the container |
| `--with-syncthing` | false | Enable Syncthing daemon for file sync with local workstation |

**Exit Codes**:

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Invalid name format |
| 2 | Name already exists |
| 3 | User container limit reached (max 5) |
| 4 | Global container limit reached (max 7) |
| 5 | Insufficient resources |
| 6 | 1Password secret retrieval failed |
| 7 | Podman error |
| 8 | Tailscale connection failed |

**Example**:

```bash
$ devbox-ctl create my-project
Creating container 'my-project'...
Retrieving Tailscale auth key from 1Password...
Starting container...
Waiting for Tailscale connection...

✓ Container 'my-project' created successfully!

Connect via SSH:    ssh dev@my-project
Connect via Zed:    Open Zed → Connect to Server → dev@my-project
Connect via Browser: https://my-project:8080 (code-server)

$ devbox-ctl create another --cpu 4 --memory 8G
Creating container 'another'...
...

$ devbox-ctl create sync-project --with-syncthing
Creating container 'sync-project'...
Retrieving Tailscale auth key from 1Password...
Starting container...
Waiting for Tailscale connection...
Starting Syncthing daemon...

✓ Container 'sync-project' created successfully!

Connect via SSH:    ssh dev@sync-project
Connect via Zed:    Open Zed → Connect to Server → dev@sync-project
Connect via Browser: https://sync-project:8080 (code-server)

Syncthing enabled:
  GUI:        http://sync-project:8384 (pair your local Syncthing here)
  Sync folder: /home/dev/sync (inside container)
```

**Behavior**:

1. Validate name format (alphanumeric + hyphens, 3-63 chars, starts with letter)
2. Check name uniqueness across all users
3. Check user's container count against limit (5)
4. Check global container count against limit (7)
5. Check available resources (CPU, memory)
6. Retrieve Tailscale auth key from 1Password (`op://{vault}/{username}-tailscale-authkey/password`)
   - Vault name from `users.nix` containers.opVault (default: `DevBox`)
   - Uses global Service Account token (`OP_SERVICE_ACCOUNT_TOKEN`)
7. Create Podman volume `{name}-data`
8. Generate Quadlet container file
9. If `--with-syncthing`, configure Syncthing daemon in container
10. Start container via systemd
11. Wait for Tailscale to connect (timeout: 60s)
12. If `--with-syncthing`, wait for Syncthing to start
13. Display connection instructions (including Syncthing URLs if enabled)

---

### devbox-ctl list

List containers owned by the current user.

```
devbox-ctl list [options]
```

**Options**:

| Option | Default | Description |
|--------|---------|-------------|
| `--all` | false | List all containers (admin only) |
| `--json` | false | Output in JSON format |
| `--state` | all | Filter by state (running, stopped, all) |

**Exit Codes**:

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Permission denied (--all without admin) |

**Example**:

```bash
$ devbox-ctl list
NAME          STATE     CREATED              LAST ACTIVITY        TAILSCALE IP
my-project    running   2025-01-25 10:00     2025-01-25 14:30     100.64.1.50
test-env      stopped   2025-01-20 09:00     2025-01-22 18:00     -

$ devbox-ctl list --json
[
  {
    "name": "my-project",
    "state": "running",
    "createdAt": "2025-01-25T10:00:00Z",
    "lastActivityAt": "2025-01-25T14:30:00Z",
    "tailscaleIP": "100.64.1.50",
    "cpuLimit": 2,
    "memoryLimit": "4G"
  }
]
```

---

### devbox-ctl start

Start a stopped container.

```
devbox-ctl start <name>
```

**Arguments**:

| Argument | Required | Description |
|----------|----------|-------------|
| `name` | Yes | Container name |

**Exit Codes**:

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Container not found |
| 2 | Container not owned by user |
| 3 | Container already running |
| 4 | Insufficient resources |
| 7 | Podman error |
| 8 | Tailscale connection failed |

**Example**:

```bash
$ devbox-ctl start test-env
Starting container 'test-env'...
Waiting for Tailscale connection...

✓ Container 'test-env' started!
  Tailscale IP: 100.64.1.51
```

---

### devbox-ctl stop

Stop a running container (preserves state).

```
devbox-ctl stop <name>
```

**Arguments**:

| Argument | Required | Description |
|----------|----------|-------------|
| `name` | Yes | Container name |

**Exit Codes**:

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Container not found |
| 2 | Container not owned by user |
| 3 | Container already stopped |
| 7 | Podman error |

**Example**:

```bash
$ devbox-ctl stop my-project
Stopping container 'my-project'...

✓ Container 'my-project' stopped.
  Data preserved in volume 'my-project-data'.
  Run 'devbox-ctl start my-project' to resume.
```

---

### devbox-ctl destroy

Permanently remove a container and its data.

```
devbox-ctl destroy <name> [options]
```

**Arguments**:

| Argument | Required | Description |
|----------|----------|-------------|
| `name` | Yes | Container name |

**Options**:

| Option | Default | Description |
|--------|---------|-------------|
| `--force` | false | Skip confirmation prompt |
| `--keep-volume` | false | Preserve data volume |

**Exit Codes**:

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Container not found |
| 2 | Container not owned by user |
| 7 | Podman error |
| 9 | Tailscale cleanup failed (warning, continues) |

**Example**:

```bash
$ devbox-ctl destroy test-env
⚠ This will permanently delete container 'test-env' and all its data.
  Continue? [y/N] y

Stopping container...
Removing Tailscale device...
Removing container...
Removing volume...

✓ Container 'test-env' destroyed.

$ devbox-ctl destroy my-project --force --keep-volume
Stopping container...
Removing Tailscale device...
Removing container...

✓ Container 'my-project' destroyed.
  Volume 'my-project-data' preserved.
```

---

### devbox-ctl status

Show detailed status of a container.

```
devbox-ctl status <name>
```

**Arguments**:

| Argument | Required | Description |
|----------|----------|-------------|
| `name` | Yes | Container name |

**Exit Codes**:

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Container not found |
| 2 | Container not owned by user |

**Example**:

```bash
$ devbox-ctl status my-project
Container: my-project
State:     running
Owner:     coal
Created:   2025-01-25 10:00:00
Activity:  2025-01-25 14:30:00 (2 hours ago)

Resources:
  CPU:     2 cores
  Memory:  4G (2.1G used)
  Disk:    15G (volume: my-project-data)

Network:
  Tailscale IP:   100.64.1.50
  Tailscale Name: my-project

Access:
  SSH:         ssh dev@my-project
  code-server: https://my-project:8080
  Zed:         Connect to Server → dev@my-project
```

---

### devbox-ctl logs

View container logs.

```
devbox-ctl logs <name> [options]
```

**Arguments**:

| Argument | Required | Description |
|----------|----------|-------------|
| `name` | Yes | Container name |

**Options**:

| Option | Default | Description |
|--------|---------|-------------|
| `--follow`, `-f` | false | Follow log output |
| `--tail` | 100 | Number of lines to show |
| `--since` | - | Show logs since timestamp |

**Exit Codes**:

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Container not found |
| 2 | Container not owned by user |

---

## Environment Variables

| Variable | Description |
|----------|-------------|
| `DEVBOX_USER` | Override current user (admin only) |
| `DEVBOX_DEBUG` | Enable debug output |
| `OP_SERVICE_ACCOUNT_TOKEN` | 1Password service account token (set by systemd) |

## Configuration

### User Limits

Configured in consumer's `users.nix` (validated by `lib/schema.nix`):

```nix
{
  containers = {
    opVault = "DevBox";        # 1Password vault name (consumer overrides)
    maxPerUser = 5;
    maxGlobal = 7;
    defaultCpu = 2;
    defaultMemory = "4G";
    idleStopDays = 7;
    stoppedDestroyDays = 14;
  };
}
```

### 1Password Setup

**Service Account (one-time, orchestrator-wide):**
- Create Service Account in 1Password with read access to your vault
- Set `OP_SERVICE_ACCOUNT_TOKEN` in systemd unit or secure secret store
- NOT per-user logins - single global token

**Vault Structure (consumer creates):**

```
DevBox/                              # Vault name (configurable in users.nix)
├── coal-tailscale-authkey           # Item per user
│   └── password: tskey-auth-xxx...  # Field containing Tailscale auth key
├── violino-tailscale-authkey
│   └── password: tskey-auth-yyy...
└── ...
```

**Naming Conventions (defined by library):**

| Component | Convention | Example |
|-----------|------------|---------|
| Item name | `{username}-tailscale-authkey` | `coal-tailscale-authkey` |
| Field | `password` | `tskey-auth-xxxx...` |
| Reference | `op://{vault}/{username}-tailscale-authkey/password` | `op://DevBox/coal-tailscale-authkey/password` |

**Tailscale Auth Key Requirements:**
- Reusable: Yes (same key for multiple containers)
- Ephemeral: Yes (devices auto-removed when container stops)
- Tags: `tag:devcontainer`, `tag:{username}-container`
- Expiry: 90 days recommended

**Tailscale ACLs (consumer manages in homelab-iac):**
- Users can only access containers with their tag
- Example: `coal@github` can only reach `tag:coal-container`

## Security Considerations

1. **Secret handling**: Auth keys retrieved via `op read` using Service Account, never stored or logged
2. **Service Account scope**: Read-only access to specific vault only
3. **User isolation**: Users can only manage their own containers (enforced by devbox-ctl)
4. **Network isolation**: Tailscale ACLs restrict SSH to container owner only (enforced externally)
5. **Resource limits**: Enforced at creation time, prevents resource exhaustion
6. **No secrets in Nix store**: Service Account token stored in systemd credential or /run/secrets

## Error Messages

All error messages follow this format:

```
Error: <brief description>
  <detailed explanation>
  <suggested action>
```

Example:

```
Error: Container limit reached
  You have 5 containers, which is the maximum allowed per user.
  Run 'devbox-ctl list' to see your containers.
  Run 'devbox-ctl destroy <name>' to remove a container.
```
