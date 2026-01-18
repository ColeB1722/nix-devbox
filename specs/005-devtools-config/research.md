# Research: Development Tools and Configuration

**Feature**: 005-devtools-config  
**Date**: 2026-01-18

## Package Availability Summary

| Tool | nixpkgs Package | Available | Notes |
|------|-----------------|-----------|-------|
| fish | `fish` | Yes | System-wide via `programs.fish.enable` |
| zellij | `zellij` | Yes | Terminal multiplexer |
| Docker | `docker` | Yes | Service via `virtualisation.docker.enable` |
| tree | `tree` | Yes | Already in home/default.nix |
| ripgrep | `ripgrep` | Yes | Already in home/default.nix |
| fzf | `fzf` | Yes | Home Manager integration available |
| bat | `bat` | Yes | Cat replacement with syntax highlighting |
| fd | `fd` | Yes | Already in home/default.nix |
| eza | `eza` | Yes | Modern ls replacement |
| lazygit | `lazygit` | Yes | Git TUI |
| gh | `gh` | Yes | GitHub CLI |
| uv | `uv` | Yes | Python package manager |
| npm | `nodejs` | Yes | Includes npm |
| terraform | `terraform` | Yes | IaC tool |
| 1Password CLI | `_1password-cli` | Yes | Unfree, requires allowUnfree |
| OpenCode | `opencode` | Yes | MIT licensed |
| Claude Code | `claude-code` | Yes | Unfree, requires allowUnfree |
| code-server | `code-server` | Yes | NixOS service module available |
| Zed remote | `zed-editor.remote_server` | Yes | In nixpkgs-unstable/25.05+ |

---

## Decision 1: Shell Configuration

**Decision**: Use Fish shell as default via NixOS + Home Manager

**Rationale**:
- Fish provides superior out-of-box experience with syntax highlighting and autocompletions
- Home Manager has excellent `programs.fish` integration
- fzf integrates seamlessly via `programs.fzf.enableFishIntegration`
- Constitution Principle II: Headless-First - Fish is fully CLI-compatible

**Configuration approach**:
```nix
# NixOS level (modules/user/default.nix)
programs.fish.enable = true;  # Add to /etc/shells
users.users.${username}.shell = pkgs.fish;

# Home Manager level (home/default.nix)
programs.fish = {
  enable = true;
  shellAbbrs = { ... };  # Use abbreviations for git, nix commands
  shellAliases = { ... };
};
programs.fzf = {
  enable = true;
  enableFishIntegration = true;
};
programs.direnv.enableFishIntegration = true;
```

**Alternatives considered**:
- Zsh: More configuration overhead, less beginner-friendly
- Bash: Already configured, but lacks modern features

---

## Decision 2: Docker Setup

**Decision**: Use NixOS `virtualisation.docker` module with user in docker group

**Rationale**:
- NixOS provides native Docker module with systemd integration
- Constitution Principle I: Declarative - all Docker config in Nix
- Adding user to `docker` group avoids sudo requirement

**Configuration approach**:
```nix
# modules/docker/default.nix (new module)
virtualisation.docker = {
  enable = true;
  enableOnBoot = true;
};

# modules/user/default.nix
users.users.${username}.extraGroups = [ "wheel" "networkmanager" "docker" ];
```

**Alternatives considered**:
- Podman: Good alternative but Docker is more widely used
- Docker via nix-shell: Constitution prohibits non-Nix config management

---

## Decision 3: AI Coding Tools

**Decision**: Install OpenCode and Claude Code via Home Manager with unfree allowed

**Rationale**:
- Both packages are available in nixpkgs
- Claude Code requires `allowUnfree` but this is acceptable for dev tools
- No custom derivations needed

**Configuration approach**:
```nix
# home/default.nix
{ pkgs, ... }: {
  nixpkgs.config.allowUnfree = true;  # Or use allowUnfreePredicate
  
  home.packages = with pkgs; [
    opencode
    claude-code
  ];
}
```

**Alternatives considered**:
- npm install: Would violate Constitution Principle I (non-declarative)
- Custom flake inputs: Unnecessary since packages exist in nixpkgs

---

## Decision 4: Remote IDE Access

**Decision**: Use code-server NixOS service + Zed remote server via Home Manager

**Rationale**:
- code-server has NixOS service module for easy systemd management
- Zed remote server available via `zed-editor.remote_server` output
- Both accessible via Tailscale network (no public exposure)
- Constitution Principle III: Security - bind to localhost/Tailscale only

**Configuration approach**:
```nix
# modules/services/code-server.nix (new module)
services.code-server = {
  enable = true;
  host = "127.0.0.1";  # Localhost only, access via Tailscale
  port = 8080;
  auth = "none";  # Safe with Tailscale network
  user = "devuser";
  disableTelemetry = true;
};

# home/default.nix - Zed remote server
home.file.".zed_server".source = "${pkgs.zed-editor.remote_server}/bin";
```

**Alternatives considered**:
- VS Code SSH extension: Requires VS Code on client, code-server works in browser
- JetBrains Gateway: Heavier, paid product

---

## Decision 5: Terminal Multiplexer

**Decision**: Use zellij instead of existing tmux

**Rationale**:
- Spec explicitly requests zellij
- More modern and user-friendly than tmux
- Better default keybindings and UI
- Can coexist with tmux for users who prefer it

**Configuration approach**:
```nix
# home/default.nix
programs.zellij = {
  enable = true;
  enableFishIntegration = true;  # Auto-attach option
};
```

**Alternatives considered**:
- Keep tmux only: Spec explicitly requests zellij
- Replace tmux: Will keep both for flexibility

---

## Decision 6: 1Password CLI

**Decision**: Install CLI-only package for headless server

**Rationale**:
- Constitution Principle II: Headless-First - no GUI needed
- CLI package works standalone with service account tokens
- Enables secret injection into development workflows

**Configuration approach**:
```nix
# NixOS level
programs._1password.enable = true;  # Creates proper group/wrapper

# home/default.nix
home.packages = [ pkgs._1password-cli ];
```

**Alternatives considered**:
- GUI package: Violates headless-first principle
- Manual install: Violates declarative configuration principle

---

## Decision 7: CodeRabbit Integration

**Decision**: Provide configuration template file, not system-level config

**Rationale**:
- CodeRabbit is a GitHub App, configured per-repository
- System-level integration not applicable
- Will include `.coderabbit.yaml` template

**Configuration approach**:
- Document CodeRabbit setup in quickstart.md
- Optionally include template config file

**Alternatives considered**:
- None - CodeRabbit is inherently repository-level

---

## Decision 8: Module Organization

**Decision**: Create new modules for distinct concerns

**New modules to create**:
```
modules/
├── shell/
│   └── default.nix      # Fish configuration (system-level)
├── docker/
│   └── default.nix      # Docker/container runtime
└── services/
    └── code-server.nix  # Remote IDE service
```

**Home Manager additions** (home/default.nix):
- Fish configuration (user-level)
- All CLI tools via `home.packages`
- fzf, bat, eza integrations
- zellij, lazygit configurations
- Zed remote server setup

**Rationale**:
- Constitution Principle IV: Modular and Reusable
- Separates system services from user tools
- Clear ownership of each concern

---

## WSL Considerations

**Docker on WSL**: 
- WSL uses Docker Desktop on Windows host, not native Docker
- Should conditionally skip `virtualisation.docker` on WSL
- Add assertion or option to handle this

**code-server on WSL**:
- Works the same, accessible via Windows browser
- May want different port to avoid conflicts

**1Password on WSL**:
- Better to use Windows 1Password app
- CLI can still work standalone

---

## Unfree Packages List

Packages requiring `allowUnfree`:
- `_1password-cli`
- `claude-code`
- `terraform` (BSL license, may need specific handling)

Configuration:
```nix
nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
  "1password-cli"
  "1password"
  "claude-code"
  "terraform"
];
```
