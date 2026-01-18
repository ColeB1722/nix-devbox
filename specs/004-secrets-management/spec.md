# 004: Secrets Management

Status: **Planned** (not yet started)

## Problem

Currently, secrets like Tailscale auth keys must be manually retrieved and injected:

```bash
# Current workflow (manual)
cd ~/repos/homelab-iac && just output tailscale shared_auth_key
sudo tailscale up --authkey=<paste-key-here>
```

This is error-prone and doesn't scale for automated deployments.

## Goals

- Programmatically inject secrets during `nixos-rebuild switch`
- Support multiple secret backends (1Password, age/sops, Vault)
- Integrate with existing homelab-iac Terraform outputs
- Enable fully automated CI/CD deployments

## Potential Approaches

1. **agenix/sops-nix** - Encrypt secrets in repo, decrypt at activation
2. **1Password CLI integration** - Fetch secrets at build/activation time
3. **Terraform data source** - Pull from homelab-iac outputs
4. **systemd credentials** - Use systemd's native secrets handling

## References

- [agenix](https://github.com/ryantm/agenix)
- [sops-nix](https://github.com/Mic92/sops-nix)
- [1Password CLI](https://developer.1password.com/docs/cli/)
- Existing: `homelab-iac` Terraform outputs for Tailscale keys

## Notes

- Must work for both bare-metal (`devbox`) and WSL (`devbox-wsl`) configurations
- Consider how this interacts with CI/CD (GitHub Actions secrets)
