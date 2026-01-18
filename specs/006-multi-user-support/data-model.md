# Data Model: Multi-User Support

**Feature**: 006-multi-user-support  
**Date**: 2026-01-18

## Entities

### User Account

Represents a system user on the NixOS devbox.

| Attribute | Type | Description | Example |
|-----------|------|-------------|---------|
| username | string | Unix username | `"coal"` |
| uid | integer | Unique user ID | `1000` |
| description | string | Human-readable name | `"coal-bap"` |
| isNormalUser | boolean | Non-system user flag | `true` |
| shell | package | Default shell | `pkgs.fish` |
| extraGroups | list[string] | Group memberships | `["wheel", "docker"]` |
| homeDirectory | string | Home directory path | `"/home/coal"` |
| sshKeys | list[string] | SSH authorized keys | `["ssh-ed25519 AAAA..."]` |
| isAdmin | boolean (derived) | Has sudo access | `true` if "wheel" in extraGroups |

**Constraints**:
- `username` must be unique across all users
- `uid` must be unique and in range 1000-60000 (normal users)
- `sshKeys` injected via environment variables at build time
- If env var is empty, a placeholder key is used (build succeeds, SSH fails)
- Placeholder key format: `ssh-ed25519 PLACEHOLDER_KEY_NOT_SET_check_SSH_KEY_envvar`
- Optional strict mode (`NIX_STRICT_KEYS=true`) fails build if keys missing

### Home Manager Configuration

Per-user environment settings managed by Home Manager.

| Attribute | Type | Description | Example |
|-----------|------|-------------|---------|
| username | string | Must match User Account username | `"coal"` |
| homeDirectory | string | Must match User Account | `"/home/coal"` |
| stateVersion | string | Home Manager state version | `"24.05"` |
| packages | list[package] | User-specific packages | `[ pkgs.htop ]` |
| programs | attrset | Program configurations | `{ git = { ... }; }` |

**Relationships**:
- 1:1 with User Account (same username)
- Imports shared common.nix module

### User Groups

System groups that grant access to shared resources.

| Group | Purpose | Members |
|-------|---------|---------|
| wheel | Sudo access | coal |
| docker | Docker daemon access | cole, violino |
| networkmanager | Network configuration | coal |

### code-server Instance

Per-user browser IDE service.

| Attribute | Type | Description | Example |
|-----------|------|-------------|---------|
| user | string | Unix user to run as | `"coal"` |
| port | integer | HTTP port | `8080` |
| host | string | Bind address | `"127.0.0.1"` |
| auth | string | Authentication mode | `"none"` (Tailscale provides auth) |
| workingDirectory | string | Default workspace | `/home/coal` |

**Instances**:
| Instance | User | Port | Active |
|----------|------|------|--------|
| code-server-coal | coal | 8080 | Yes |
| code-server-violino | violino | 8081 | Yes (but Tailscale ACL may block) |

## Configuration Structure

### Environment Variables

Required for deployment builds (not for FlakeHub publish):

| Variable | Description | Example |
|----------|-------------|---------|
| `SSH_KEY_COAL` | Cole's SSH public key | `ssh-ed25519 AAAA...` |
| `SSH_KEY_VIOLINO` | Violino's SSH public key | `ssh-ed25519 AAAA...` |

### File Structure

```
modules/user/default.nix
├── User definitions (cole, violino)
├── SSH key injection from env vars
├── Group memberships
└── Home Manager user mappings

home/
├── common.nix          # Shared configuration
│   ├── packages        # CLI tools, utilities
│   ├── programs.fish   # Shell config
│   ├── programs.fzf    # Fuzzy finder
│   ├── programs.bat    # Syntax highlighting
│   ├── programs.eza    # Modern ls
│   └── programs.*      # Other shared programs
│
├── coal.nix            # Cole's personal config
│   ├── imports = [ ./common.nix ]
│   ├── home.username = "coal"
│   ├── programs.git.userName = "coal-bap"
│   └── [personal customizations]
│
└── violino.nix         # Violino's personal config
    ├── imports = [ ./common.nix ]
    ├── home.username = "violino"
    ├── programs.git.userName = "Violino"
    └── [personal customizations]
```

## State Transitions

### User Account Lifecycle

```
[Not Exists] 
    │
    ▼ (nixos-rebuild switch with user defined)
[Created]
    │
    ├─► [Active] ◄─────────────────────┐
    │       │                          │
    │       ▼ (SSH key removed)        │
    │   [Locked Out]                   │
    │       │                          │
    │       ▼ (SSH key re-added)       │
    │       └──────────────────────────┘
    │
    ▼ (user removed from config)
[Deleted]
```

### code-server Instance Lifecycle

```
[Disabled]
    │
    ▼ (enable = true in config)
[Enabled]
    │
    ├─► [Running] ◄──────────────┐
    │       │                    │
    │       ▼ (systemctl stop)   │
    │   [Stopped]                │
    │       │                    │
    │       ▼ (systemctl start)  │
    │       └────────────────────┘
    │
    ▼ (enable = false)
[Disabled]
```

## Validation Rules

### SSH Key Validation

1. Key format: Must start with valid SSH key type (`ssh-ed25519`, `ssh-rsa`, etc.)
2. Non-empty: Each user must have at least one key (for deploy builds)
3. Non-placeholder: Keys must not contain "PLACEHOLDER" or similar markers

### User Configuration Validation

1. Unique usernames across all defined users
2. Unique UIDs (no collisions)
3. Admin user (coal) must be in wheel group
4. Non-admin user (violino) must NOT be in wheel group

### code-server Validation

1. Unique ports per instance
2. User must exist before code-server can run as that user
3. Tailscale must be enabled (existing assertion)
