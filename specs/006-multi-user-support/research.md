# Research: Multi-User Support

**Feature**: 006-multi-user-support  
**Date**: 2026-01-18

## Research Topics

### 1. Environment Variable Injection for SSH Keys

**Decision**: Use `builtins.getEnv` to read SSH public keys from environment variables at Nix evaluation time.

**Rationale**:
- `builtins.getEnv "VAR"` returns the value of environment variable `VAR` at evaluation time
- Returns empty string `""` if variable is not set (allows for placeholder/fallback logic)
- Keys are only embedded in the derivation if env vars are set during evaluation
- CI publish job without env vars → FlakeHub flake has empty/placeholder keys
- Deploy job with env vars → actual keys embedded in deployed configuration

**Pattern**:
```nix
let
  coleKey = builtins.getEnv "SSH_KEY_COLE";
  violinoKey = builtins.getEnv "SSH_KEY_VIOLINO";
  
  # Placeholder used when env var not set - allows FlakeHub publish to succeed
  # The placeholder is obviously invalid and will be caught by SSH
  placeholder = "ssh-ed25519 PLACEHOLDER_KEY_NOT_SET_check_env_vars";
in
{
  users.users.cole.openssh.authorizedKeys.keys = [
    (if coleKey != "" then coleKey else placeholder)
  ];
}
```

**Graceful Handling**:
- If env var is set: Real key is used
- If env var is empty: Placeholder key is used
- Placeholder allows build to succeed (for FlakeHub)
- Placeholder is obviously invalid - SSH auth will fail with clear reason
- Optional: Add `lib.warn` to print warning during evaluation when placeholder is used

**Alternatives Considered**:
| Alternative | Why Rejected |
|-------------|--------------|
| Hardcoded keys | Keys visible in public repo and FlakeHub |
| Flake input override | More complex deploy workflow, harder for users |
| agenix/sops-nix | Overkill for public keys; designed for secrets |
| External file reference | Requires file management outside Nix |

**CI Safety**:
- Publish job: Do NOT set `SSH_KEY_*` environment variables
- Deploy job: Set `SSH_KEY_*` from GitHub secrets or local `.env`
- FlakeHub receives flake evaluated without keys → safe to publish

---

### 2. Multi-User Home Manager Configuration

**Decision**: Use per-user Home Manager configs with a shared common module.

**Rationale**:
- NixOS module `home-manager.users.<name>` allows per-user configuration
- Shared config (packages, shell, tools) extracted to `home/common.nix`
- User-specific config (git identity, personal aliases) in `home/<user>.nix`
- Each user imports common + their personal config

**Pattern**:
```nix
# In modules/user/default.nix or host config
home-manager.users.cole = import ../../home/cole.nix;
home-manager.users.violino = import ../../home/violino.nix;

# home/cole.nix
{ pkgs, ... }: {
  imports = [ ./common.nix ];
  
  home.username = "cole";
  home.homeDirectory = "/home/cole";
  
  programs.git = {
    userName = "Cole Bateman";
    userEmail = "cole@example.com";
  };
}

# home/common.nix
{ pkgs, ... }: {
  # Shared packages, shell config, tools
  programs.fish.enable = true;
  programs.fzf.enable = true;
  # ... etc
}
```

**Alternatives Considered**:
| Alternative | Why Rejected |
|-------------|--------------|
| Single home.nix with conditionals | Messy, hard to maintain per-user differences |
| Standalone home-manager (not NixOS module) | Requires separate `home-manager switch` commands |
| No Home Manager (system packages only) | Loses per-user environment customization |

---

### 3. Per-User code-server Instances

**Decision**: Run separate code-server systemd services per user on different ports.

**Rationale**:
- code-server is single-user by design (runs as one user, serves one workspace)
- Multiple instances on different ports provide isolation
- Each instance runs under the respective user's UID
- Tailscale ACL controls who can access which port

**Pattern**:
```nix
# NixOS doesn't have built-in multi-instance code-server
# Options:
# 1. Use systemd service template
# 2. Define multiple services manually
# 3. Create a custom module with user parameter

# Recommended: Custom module with per-user services
services.code-server-cole = {
  enable = true;
  user = "cole";
  port = 8080;
  host = "127.0.0.1";
};

services.code-server-violino = {
  enable = true;
  user = "violino";
  port = 8081;
  host = "127.0.0.1";
};
```

**Implementation Approach**:
Since NixOS `services.code-server` is single-instance, we'll either:
1. Create a wrapper module that generates multiple systemd services
2. Use `systemd.services` directly to define per-user code-server units

**Port Assignments**:
| User | code-server Port | Notes |
|------|------------------|-------|
| Cole | 8080 | Admin user, full Tailscale access |
| Violino | 8081 | SSH-only per Tailscale ACL (may not use code-server) |

**Note**: Per Tailscale ACL, Violino only has SSH access (port 22). Her code-server instance (8081) would only be accessible if ACL is updated. Consider making her code-server optional.

**Alternatives Considered**:
| Alternative | Why Rejected |
|-------------|--------------|
| Single shared code-server | No user isolation, shared workspace |
| code-server with built-in auth | Adds complexity; Tailscale provides network auth |
| No code-server for Violino | Could work, but limits her options if ACL changes |

---

### 4. User Account Structure

**Decision**: Named user accounts (`cole`, `violino`) with explicit UIDs for reproducibility.

**Rationale**:
- Named accounts are clearer than generic "devuser"
- Explicit UIDs ensure consistent ownership across rebuilds
- Aligns with FR-009: "usernames that identify each user"

**Pattern**:
```nix
users.users = {
  cole = {
    isNormalUser = true;
    uid = 1000;
    description = "Cole Bateman";
    extraGroups = [ "wheel" "docker" "networkmanager" ];
    shell = pkgs.fish;
    openssh.authorizedKeys.keys = [ /* from env var */ ];
  };
  
  violino = {
    isNormalUser = true;
    uid = 1001;
    description = "Violino";
    extraGroups = [ "docker" ];  # No wheel = no sudo
    shell = pkgs.fish;
    openssh.authorizedKeys.keys = [ /* from env var */ ];
  };
};
```

**UID Assignments**:
| User | UID | Groups | Sudo |
|------|-----|--------|------|
| cole | 1000 | wheel, docker, networkmanager | Yes (passwordless) |
| violino | 1001 | docker | No |

---

### 5. SSH Key Assertion Pattern

**Decision**: Extend existing SSH key assertion to handle multiple users with env-var-injected keys.

**Rationale**:
- Current assertion checks for non-empty, non-placeholder keys
- Need to check each user independently
- Allow builds with empty keys (for FlakeHub publish) but warn/fail on deploy

**Pattern**:
```nix
# For FlakeHub-safe builds, we can't hard-fail on missing keys
# Instead, use a softer check or make assertion configurable

assertions = lib.optionals (builtins.getEnv "NIX_DEPLOY_MODE" == "true") [
  {
    assertion = (builtins.length config.users.users.cole.openssh.authorizedKeys.keys) > 0;
    message = "Cole's SSH key not configured. Set SSH_KEY_COLE environment variable.";
  }
  {
    assertion = (builtins.length config.users.users.violino.openssh.authorizedKeys.keys) > 0;
    message = "Violino's SSH key not configured. Set SSH_KEY_VIOLINO environment variable.";
  }
];
```

**Alternative**: Use `lib.mkDefault` with placeholder values that get overridden by env vars, and only assert during actual deployment.

---

## Summary

| Topic | Decision | Key Benefit |
|-------|----------|-------------|
| SSH Key Injection | `builtins.getEnv` | FlakeHub-safe, no hardcoded keys |
| Home Manager | Per-user configs + common module | Clean separation, shared tooling |
| code-server | Per-user systemd services | User isolation |
| User Accounts | Named accounts with explicit UIDs | Clarity, reproducibility |
| Assertions | Configurable based on deploy mode | Works for both publish and deploy |
