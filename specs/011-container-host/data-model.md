# Data Model: Container Host

**Feature**: 011-container-host  
**Date**: 2025-01-31  
**Status**: Complete

## Entities

### User

Extends existing `lib/users.nix` schema with resource quota support.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | ✅ | Username (must match attribute key) |
| `uid` | int | ✅ | User ID (1000-65533) |
| `description` | string | ✅ | GECOS field |
| `email` | string | ✅ | For git config |
| `gitUser` | string | ✅ | For git config |
| `isAdmin` | bool | ✅ | If true, added to `wheel`; can view all containers |
| `sshKeys` | list[string] | ❌ | **Deprecated for container-host** — auth via Tailscale SSH |
| `extraGroups` | list[string] | ❌ | Additional groups |
| `resourceQuota` | ResourceQuota | ❌ | Per-user resource limits (if absent, unlimited) |

**Notes**:
- `sshKeys` field becomes optional/ignored on `container-host` since authentication is via Tailscale OAuth
- `isAdmin = true` users bypass resource quotas and can inspect other users' containers

---

### ResourceQuota

New nested record for per-user resource limits.

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `cpuCores` | int | ❌ | unlimited | Max CPU cores (systemd CPUQuota = N × 100%) |
| `memoryGB` | int | ❌ | unlimited | Max memory in GB (systemd MemoryMax) |
| `storageGB` | int | ❌ | unlimited | Max container storage in GB (filesystem quota) |

**Validation Rules**:
- `cpuCores` must be >= 1 if specified
- `memoryGB` must be >= 1 if specified
- `storageGB` must be >= 1 if specified

**Enforcement**:
- CPU/memory: systemd user slice `user-<uid>.slice`
- Storage: filesystem quota on `/home` or container storage path

---

### Container (Runtime Entity)

Not persisted in Nix config — exists at runtime in Podman.

| Attribute | Source | Description |
|-----------|--------|-------------|
| `id` | Podman | Container ID (SHA256 prefix) |
| `name` | Podman | Human-readable container name |
| `owner` | System | UID of user who created the container |
| `state` | Podman | running, paused, stopped, etc. |
| `created` | Podman | Timestamp |
| `image` | Podman | Source image reference |

**Isolation Properties**:
- Container is visible only to its `owner` (via rootless Podman namespace)
- Admin users can access any container via `sudo -u <owner> podman ...`

---

### Tailscale ACL (External Entity)

Managed outside this system in Tailscale admin console.

| Concept | Description |
|---------|-------------|
| `tag:container-host` | Tag applied to the host machine |
| `group:devs` | Group of users permitted to SSH |
| `ssh.action: check` | Requires OAuth re-authentication |

**Example ACL snippet** (for reference, not managed by Nix):
```json
{
  "tagOwners": {
    "tag:container-host": ["autogroup:admin"]
  },
  "ssh": [
    {
      "action": "check",
      "src": ["group:devs"],
      "dst": ["tag:container-host"],
      "users": ["autogroup:nonroot"]
    }
  ]
}
```

---

## Relationships

```
┌─────────────────────────────────────────────────────────────┐
│                     Tailscale ACL                           │
│                   (external, managed                        │
│                    in Tailscale admin)                      │
└─────────────────────┬───────────────────────────────────────┘
                      │ grants SSH access
                      ▼
┌─────────────────────────────────────────────────────────────┐
│                        User                                 │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ name, uid, isAdmin, resourceQuota                   │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────┬───────────────────────────────────────┘
                      │ owns 0..*
                      ▼
┌─────────────────────────────────────────────────────────────┐
│                     Container                               │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ id, name, state, image                              │   │
│  │ subject to owner's resourceQuota                    │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## State Transitions

### User Lifecycle

```
[Created in users.nix] 
    │
    ▼ nixos-rebuild switch
[System user created]
    │
    ▼ First SSH login
[Podman initialized (~/.local/share/containers)]
    │
    ▼ User runs containers
[Active]
    │
    ▼ Removed from users.nix
[Disabled/Removed]
```

### Container Lifecycle

```
[pulled/built] → [created] → [running] ⇄ [paused] → [stopped] → [removed]
                     │                                   ▲
                     └───────────────────────────────────┘
```

All transitions are user-initiated via `podman` CLI. No automated container management.

---

## Example User Definition

```nix
{
  alice = {
    name = "alice";
    uid = 1001;
    description = "Alice - Agent Developer";
    email = "alice@example.com";
    gitUser = "alice";
    isAdmin = false;
    sshKeys = [ ]; # Empty — Tailscale SSH handles auth
    extraGroups = [ ];
    resourceQuota = {
      cpuCores = 2;
      memoryGB = 4;
      storageGB = 50;
    };
  };

  bob = {
    name = "bob";
    uid = 1002;
    description = "Bob - Platform Admin";
    email = "bob@example.com";
    gitUser = "bob";
    isAdmin = true;
    sshKeys = [ ];
    extraGroups = [ ];
    # No resourceQuota — admins are unlimited
  };

  allUserNames = [ "alice" "bob" ];
  adminUserNames = [ "bob" ];
}
```
