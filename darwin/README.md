# Darwin Modules (nix-darwin)

This directory will contain nix-darwin modules for macOS configuration.

## Status

🚧 **Not yet implemented** - Placeholder for future macOS support.

## Planned Structure

```
darwin/
├── core.nix        # macOS system settings (defaults write, etc.)
├── ssh.nix         # SSH daemon configuration
├── tailscale.nix   # Tailscale via launchd
├── homebrew.nix    # Homebrew integration (if needed)
└── users.nix       # macOS user configuration
```

## Key Differences from NixOS

- Uses **launchd** instead of systemd for services
- Uses **pf** (packet filter) instead of iptables for firewall
- Uses **dscl** commands for user management
- Different paths and conventions for config files

## Home Manager

Home Manager works identically on Darwin - the `home/` directory modules
are fully compatible and can be reused without modification.

## Resources

- [nix-darwin](https://github.com/LnL7/nix-darwin)
- [nix-darwin options](https://daiderd.com/nix-darwin/manual/index.html)