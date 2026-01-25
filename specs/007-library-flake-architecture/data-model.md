# Data Model: User Data Schema

**Feature**: 007-library-flake-architecture  
**Date**: 2025-01-22  
**Status**: Complete

## Overview

This document defines the schema for user data that consumers must provide when using the nix-devbox library flake. The schema is validated at evaluation time using Nix assertions.

## User Data Structure

Consumer repositories must provide a `users.nix` file with the following structure:

```nix
# users.nix - Consumer's user data
{
  # ─────────────────────────────────────────────────────────────────────────────
  # User Records
  # ─────────────────────────────────────────────────────────────────────────────
  # Define one or more user records. The attribute name must match the `name` field.

  <username> = {
    name = "<username>";           # REQUIRED: string, must match attribute name
    uid = <integer>;               # REQUIRED: 1000-65533, not in system range
    description = "<string>";      # REQUIRED: non-empty string
    email = "<email>";             # REQUIRED: non-empty string (used for git)
    gitUser = "<github-username>"; # REQUIRED: non-empty string (GitHub username)
    isAdmin = <boolean>;           # REQUIRED: true = wheel group (sudo access)
    sshKeys = [ "<pubkey>" ... ];  # REQUIRED: non-empty list of SSH public keys
    extraGroups = [ "<group>" ];   # OPTIONAL: additional groups (default: [])
  };

  # ─────────────────────────────────────────────────────────────────────────────
  # Collection Fields
  # ─────────────────────────────────────────────────────────────────────────────
  # These fields aggregate user information for iteration in modules.

  allUserNames = [ "<username1>" "<username2>" ... ];  # REQUIRED: all user names
  adminUserNames = [ "<username>" ... ];               # REQUIRED: users with isAdmin=true

  # ─────────────────────────────────────────────────────────────────────────────
  # Service Configuration
  # ─────────────────────────────────────────────────────────────────────────────

  codeServerPorts = {
    <username> = <port>;  # REQUIRED per user: port for code-server (8080-8099 recommended)
  };
}
```

## Field Specifications

### User Record Fields

| Field | Type | Required | Constraints | Description |
|-------|------|----------|-------------|-------------|
| `name` | string | Yes | Must match attribute key | Username for system account |
| `uid` | integer | Yes | 1000 ≤ uid ≤ 65533 | User ID (not 0, not system range) |
| `description` | string | Yes | Non-empty | Human-readable description |
| `email` | string | Yes | Non-empty | Email address for git commits |
| `gitUser` | string | Yes | Non-empty | GitHub/git username |
| `isAdmin` | boolean | Yes | - | If true, user gets wheel group |
| `sshKeys` | list of strings | Yes | Non-empty, valid SSH format | SSH public keys for authentication |
| `extraGroups` | list of strings | No | Valid group names | Additional group memberships |

### Collection Fields

| Field | Type | Required | Constraints | Description |
|-------|------|----------|-------------|-------------|
| `allUserNames` | list of strings | Yes | Non-empty | All defined usernames |
| `adminUserNames` | list of strings | Yes | Subset of allUserNames | Users where isAdmin = true |
| `codeServerPorts` | attrset | Yes | One entry per user | Port assignments for code-server |

## Validation Rules

### Security Validations (FR-018, FR-019)

1. **UID Range**: `uid` must be ≥ 1000 and ≤ 65533
   - UID 0 is root (forbidden)
   - UIDs 1-999 are system accounts (forbidden)
   
2. **SSH Key Format**: Each key in `sshKeys` must:
   - Start with `ssh-` (e.g., `ssh-ed25519`, `ssh-rsa`)
   - Be non-empty
   
3. **Non-empty Strings**: `name`, `description`, `email`, `gitUser` must be non-empty

4. **Admin Consistency**: Users in `adminUserNames` must have `isAdmin = true`

### Structural Validations

1. **Attribute Name Match**: The attribute key must equal the `name` field value
2. **Collection Consistency**: All users in `allUserNames` must have corresponding records
3. **Port Uniqueness**: Each user must have a unique `codeServerPorts` entry

## Example: Complete users.nix

```nix
# Example consumer users.nix
{
  # ─────────────────────────────────────────────────────────────────────────────
  # alice - Primary Administrator
  # ─────────────────────────────────────────────────────────────────────────────
  alice = {
    name = "alice";
    uid = 1000;
    description = "Alice - Primary Administrator";
    email = "alice@example.com";
    gitUser = "alice-gh";
    isAdmin = true;
    sshKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIExampleKeyAlice1234567890 alice@laptop"
    ];
    extraGroups = [ "networkmanager" ];
  };

  # ─────────────────────────────────────────────────────────────────────────────
  # bob - Developer (no admin)
  # ─────────────────────────────────────────────────────────────────────────────
  bob = {
    name = "bob";
    uid = 1001;
    description = "Bob - Developer";
    email = "bob@example.com";
    gitUser = "bob-dev";
    isAdmin = false;
    sshKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIExampleKeyBob1234567890 bob@workstation"
    ];
    extraGroups = [ ];
  };

  # ─────────────────────────────────────────────────────────────────────────────
  # Collection Fields
  # ─────────────────────────────────────────────────────────────────────────────
  allUserNames = [ "alice" "bob" ];
  adminUserNames = [ "alice" ];

  # ─────────────────────────────────────────────────────────────────────────────
  # Service Configuration
  # ─────────────────────────────────────────────────────────────────────────────
  codeServerPorts = {
    alice = 8080;
    bob = 8081;
  };
}
```

## Example: Minimal Single-User

```nix
# Minimal users.nix for single user
{
  myuser = {
    name = "myuser";
    uid = 1000;
    description = "My User";
    email = "me@example.com";
    gitUser = "myusername";
    isAdmin = true;
    sshKeys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI..." ];
    extraGroups = [ ];
  };

  allUserNames = [ "myuser" ];
  adminUserNames = [ "myuser" ];
  codeServerPorts = { myuser = 8080; };
}
```

## Error Messages

When validation fails, the system produces clear, actionable error messages:

| Condition | Error Message |
|-----------|---------------|
| Missing field | `User 'alice' is missing required fields: email, sshKeys` |
| Invalid UID | `User 'alice' uid must be 1000-65533 (got 500)` |
| UID is root | `User 'alice' uid cannot be 0 (root)` |
| Empty sshKeys | `User 'alice' must have at least one SSH public key` |
| Invalid SSH format | `User 'alice' has invalid SSH key format (must start with 'ssh-')` |
| Missing allUserNames | `users.nix must define 'allUserNames' list` |
| Missing adminUserNames | `users.nix must define 'adminUserNames' list` |

## Schema Versioning

The schema version is implicit in the public flake version. When breaking changes occur:

1. Build fails with informative error message
2. Error includes migration instructions
3. Changelog documents required changes

See [spec.md Clarifications](./spec.md#clarifications) for versioning policy.

## Related Documents

- [spec.md](./spec.md) - Feature specification
- [contracts/user-data-schema.nix](./contracts/user-data-schema.nix) - Nix implementation
- [quickstart.md](./quickstart.md) - Consumer setup guide