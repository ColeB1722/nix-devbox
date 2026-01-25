# Container Builds (dockertools)

This directory will contain container image definitions using Nix's `dockerTools`.

## Status

🚧 **Not yet implemented** - Placeholder for future container support.

## Planned Structure

```
containers/
├── base.nix        # Minimal CLI environment (core tools only)
├── devenv.nix      # Full development environment image
└── lib.nix         # Shared container build helpers
```

## How It Works

Unlike NixOS and Darwin, containers don't use a module system at runtime.
Instead, we use `dockerTools.buildImage` to create OCI-compliant images
with packages baked in at build time.

### Example

```nix
# containers/base.nix
{ pkgs }:

pkgs.dockerTools.buildImage {
  name = "devbox-base";
  tag = "latest";

  contents = with pkgs; [
    # Pull package list from home/modules/cli.nix
    coreutils
    curl
    ripgrep
    fd
    bat
    eza
    jq
    fish
  ];

  config = {
    Cmd = [ "${pkgs.fish}/bin/fish" ];
    Env = [ "TERM=xterm-256color" ];
  };
}
```

## Sharing with Home Manager

The package lists in `home/modules/cli.nix` and `home/modules/dev.nix`
can be extracted and reused for container builds to ensure consistency
across platforms.

## Building

```bash
# Build a container image
nix build .#containers.base

# Load into Docker
docker load < result

# Run
docker run -it devbox-base:latest
```

## Resources

- [dockerTools documentation](https://nixos.org/manual/nixpkgs/stable/#sec-pkgs-dockerTools)
- [Building Docker images with Nix](https://nix.dev/tutorials/nixos/building-and-running-docker-images)