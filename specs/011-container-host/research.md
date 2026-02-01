# Research: Container Host

**Feature**: 011-container-host  
**Date**: 2025-01-31  
**Status**: Complete

## Research Areas

### 1. Tailscale SSH with OAuth

**Decision**: Use Tailscale SSH with `tailscale.com/ssh: check` ACL tags to enable OAuth-based authentication

**Rationale**:
- Tailscale SSH acts as a proxy, authenticating users via their Tailscale identity (backed by OIDC providers like Google, GitHub, Okta)
- No SSH keys need to be committed to the repository
- ACLs are managed centrally in Tailscale admin console
- NixOS just needs to accept connections on the Tailscale interface; Tailscale handles auth

**Alternatives Considered**:
- **Traditional SSH keys in `users.nix`**: Rejected — keys in repo are a security risk; key rotation is manual
- **SSH Certificate Authority**: Rejected — adds complexity; Tailscale already solves this
- **Teleport/Boundary**: Rejected — additional infrastructure; Tailscale is already in use

**Implementation Notes**:
- Disable `services.openssh` listening on non-Tailscale interfaces
- Set `services.tailscale.ssh.enable = true` (NixOS 25.05+)
- Configure Tailscale ACLs externally: `"ssh": [{"action": "check", "src": ["group:devs"], "dst": ["tag:container-host"]}]`

---

### 2. Rootless Podman Per-User Isolation

**Decision**: Use Podman's native rootless mode with systemd user services and separate XDG runtime directories

**Rationale**:
- Podman rootless runs containers as the user's UID — no root daemon
- Each user gets isolated `/run/user/<uid>/podman/` socket
- Containers are stored in `~/.local/share/containers/`
- No cross-user visibility by design (different namespaces)

**Alternatives Considered**:
- **Docker with userns-remap**: Rejected — still requires root daemon; complexity
- **Podman with shared socket + ACLs**: Rejected — harder to isolate; single point of failure
- **Kubernetes/k3s**: Rejected — overkill for single-host multi-user; significant overhead

**Implementation Notes**:
- Enable `virtualisation.podman.enable = true` with `dockerCompat = false` (avoid conflicts)
- Ensure `subuid`/`subgid` ranges are allocated per user in `users.nix`
- Initialize rootless Podman on first login via `podman system migrate` in user profile

---

### 3. Per-User Resource Quotas

**Decision**: Use cgroups v2 (systemd slices) for CPU/memory limits; filesystem quotas for storage

**Rationale**:
- cgroups v2 is the modern, unified interface for resource control
- systemd user slices (`user-<uid>.slice`) automatically group all user processes
- Filesystem quotas (ext4/xfs/btrfs) limit storage per user
- Podman respects cgroup limits when running rootless containers

**Alternatives Considered**:
- **Container-level limits only**: Rejected — user can spawn unlimited containers; need user-level caps
- **LXC/systemd-nspawn per user**: Rejected — heavier isolation than needed; Podman already provides namespaces
- **Manual cgroup configuration**: Rejected — systemd slices are declarative and integrated

**Implementation Notes**:
- Set `systemd.slices."user-<uid>".sliceConfig` with `MemoryMax`, `CPUQuota`
- Enable filesystem quotas in hardware config: `fileSystems."/".options = ["usrquota"]`
- Use `setquota` or declarative quota module to set per-user storage limits
- Store quota config in `users.nix` under new `resourceQuota` field

---

### 4. Minimal Service Set

**Decision**: Create new host `container-host` that imports only: `core.nix`, `ssh.nix`, `tailscale.nix`, `fish.nix`, `users.nix`, `firewall.nix`, and new `podman-isolation.nix`

**Rationale**:
- `devbox` includes code-server, ttyd, syncthing, hyprland — none needed here
- Fewer services = smaller attack surface
- Lean host boots faster, uses less memory

**Excluded from `devbox`**:
- `code-server.nix` — web UI, not needed
- `ttyd.nix` — web terminal, not needed
- `syncthing.nix` — file sync, not needed
- `hyprland.nix` — GUI, definitely not needed

**Implementation Notes**:
- New host file: `hosts/container-host/default.nix`
- Explicitly does NOT import optional service modules
- Firewall allows only Tailscale interface

---

### 5. Admin Container Oversight

**Decision**: Admin users run `podman --remote` against other users' sockets via sudo, or use `machinectl` for systemd-level visibility

**Rationale**:
- Podman has no central daemon to query
- Admins with sudo can access any user's Podman socket: `sudo -u <user> podman ps`
- `systemd-cgls` shows all user slices and their processes
- Keeps admin tooling simple without additional services

**Alternatives Considered**:
- **Cockpit/Portainer**: Rejected — web UI violates headless-first; extra attack surface
- **Central Podman socket with ACLs**: Rejected — breaks user isolation model
- **Custom admin CLI tool**: Rejected — standard tools suffice

**Implementation Notes**:
- Document admin commands in quickstart
- Optionally create shell aliases for admins: `pall` → iterate all users' `podman ps`
- Consider simple script in `/usr/local/bin/podman-admin` for convenience

---

### 6. Preventing Nested Containers

**Decision**: Disable Podman-in-Podman by not granting `--privileged` and restricting device access

**Rationale**:
- Nested containers are a security risk (escape vectors)
- Agent workloads don't need nested containers
- Podman rootless without `--privileged` cannot create nested namespaces

**Implementation Notes**:
- Default Podman config already restricts this
- Document that `--privileged` is blocked
- Consider `containers.conf` setting: `no_new_privileges = true`

---

## Schema Changes

### `lib/users.nix` — New Fields

```nix
exampleuser = {
  # ... existing fields ...
  resourceQuota = {
    cpuCores = 2;        # Maximum CPU cores (via CPUQuota)
    memoryGB = 4;        # Maximum memory in GB (via MemoryMax)
    storageGB = 50;      # Maximum storage in GB (via filesystem quota)
  };
};
```

### `lib/schema.nix` — New Validators

- `validResourceQuota`: Validate `cpuCores` (int, >= 1), `memoryGB` (int, >= 1), `storageGB` (int, >= 1)
- Field is optional; if absent, no limits applied (admin users)

---

## Open Questions Resolved

| Question | Resolution |
|----------|------------|
| How does Tailscale SSH integrate with NixOS? | `services.tailscale.ssh.enable = true` in NixOS 25.05+ |
| How to prevent cross-user container access? | Rootless Podman + separate user namespaces (built-in) |
| How to enforce resource limits? | systemd user slices + filesystem quotas |
| How do admins see all containers? | `sudo -u <user> podman ps` or systemd-cgls |
| How to prevent nested containers? | No `--privileged`, default Podman security |

---

## Next Steps

Proceed to Phase 1: Generate `data-model.md` and `quickstart.md`. No API contracts needed (CLI-only).