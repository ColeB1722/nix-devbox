# Contracts: Container Host

This feature has no API contracts.

Container Host is a CLI-only NixOS configuration. All user interaction is via:

- **SSH** (Tailscale SSH with OAuth)
- **Podman CLI** (rootless, per-user)
- **Standard Unix tools** (systemctl, quota, etc.)

No REST/GraphQL/RPC APIs are exposed.