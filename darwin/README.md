# Darwin Modules (nix-darwin)

This directory contains nix-darwin modules for macOS workstation configuration.

## Status

✅ **Implemented** - Full macOS workstation support with Aerospace tiling.

## Structure

```
darwin/
├── README.md        # This file
├── core.nix         # Base macOS system configuration
└── aerospace.nix    # Aerospace tiling window manager
```

## Modules

### core.nix

Base macOS system configuration including:

- **Nix Configuration**: Flakes enabled, binary caches, garbage collection
- **System Defaults**: Finder, Dock, keyboard, trackpad settings
- **Security**: Touch ID for sudo, screen lock settings
- **Shell**: Fish shell enabled system-wide

Key settings applied:
- Dark mode enabled
- Fast key repeat (for Vim users)
- Tap-to-click and three-finger drag
- Auto-hide Dock with no delay
- Screenshots saved to `~/Screenshots` as PNG

### aerospace.nix

[Aerospace](https://github.com/nikitabobko/AeroSpace) tiling window manager:

- Installed via Homebrew cask
- Vim-style keybindings (Alt + H/J/K/L)
- 9 workspaces with Alt + 1-9
- Resize mode (Alt + R)
- Auto-start at login

**Default Keybindings:**

| Key | Action |
|-----|--------|
| `Alt + H/J/K/L` | Focus left/down/up/right |
| `Alt + Shift + H/J/K/L` | Move window |
| `Alt + 1-9` | Switch workspace |
| `Alt + Shift + 1-9` | Move to workspace |
| `Alt + F` | Toggle fullscreen |
| `Alt + Shift + F` | Toggle floating |
| `Alt + R` | Enter resize mode |
| `Alt + Shift + Q` | Close window |

## Usage

### First-Time Bootstrap

```bash
# Install Nix (if not already installed)
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

# Clone repository
git clone https://github.com/yourusername/nix-devbox.git
cd nix-devbox

# Bootstrap nix-darwin
nix run nix-darwin -- switch --flake .#macbook
```

### Subsequent Updates

```bash
darwin-rebuild switch --flake .#macbook
```

### Consumer Configuration

In your private repo, create a darwin configuration:

```nix
# flake.nix
{
  inputs.nix-devbox.url = "github:yourusername/nix-devbox";

  outputs = { self, nix-devbox, ... }: {
    darwinConfigurations.my-mac = nix-devbox.inputs.nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";  # or "x86_64-darwin" for Intel
      modules = [
        nix-devbox.darwinModules.default
        nix-devbox.hosts.macbook
        ./my-overrides.nix
      ];
    };
  };
}
```

## Key Differences from NixOS

| Aspect | NixOS | nix-darwin |
|--------|-------|------------|
| Service manager | systemd | launchd |
| Firewall | iptables/nftables | pf (packet filter) |
| User management | declarative | mostly manual (System Preferences) |
| Package management | Full system | User packages + some system |
| Init system | NixOS modules | nix-darwin modules |

## Home Manager Integration

Home Manager works identically on Darwin. The `home/` directory modules
are fully compatible:

- `home/modules/cli.nix` - CLI tools (ripgrep, fd, bat, etc.)
- `home/modules/fish.nix` - Fish shell configuration
- `home/modules/git.nix` - Git with lazygit and gh
- `home/modules/dev.nix` - Development tools (neovim, nodejs, etc.)

Use the `workstation` profile for local development:

```nix
home-manager.users.myuser = {
  imports = [ nix-devbox.homeManagerModules.profiles.workstation ];
};
```

## Homebrew Integration

Some GUI apps aren't available in nixpkgs. nix-darwin can manage Homebrew:

```nix
# In your configuration
homebrew = {
  enable = true;
  casks = [
    "obsidian"
    "discord"
    "slack"
  ];
  masApps = {
    "Xcode" = 497799835;
  };
};
```

## Troubleshooting

### darwin-rebuild fails with permission error

```bash
# For multi-user Nix installations (recommended), run with sudo:
sudo darwin-rebuild switch --flake .#macbook

# For single-user Nix installations only (will break multi-user setups):
# sudo chown -R $(whoami) /nix
```

> **Warning**: Running `sudo chown -R $(whoami) /nix` on a multi-user Nix
> installation will break permissions for other users. Only use this on
> single-user installations.

### Aerospace not starting

```bash
# Check if installed
brew list --cask | grep aerospace

# Start manually
open -a AeroSpace

# Check logs
cat ~/Library/Logs/AeroSpace/aerospace.log
```

### Homebrew casks not installing

```bash
# Ensure Homebrew is installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Run darwin-rebuild again
darwin-rebuild switch --flake .#macbook
```

## Resources

- [nix-darwin](https://github.com/LnL7/nix-darwin)
- [nix-darwin options](https://daiderd.com/nix-darwin/manual/index.html)
- [Aerospace documentation](https://nikitabobko.github.io/AeroSpace/guide)
- [Determinate Nix Installer](https://github.com/DeterminateSystems/nix-installer)