# Dev Container Image Definition
#
# This module builds the OCI container image for dev containers using
# Nix's dockerTools. It creates a layered image with:
#   - Base layer: coreutils, bash, shadow (for user management)
#   - CLI tools layer: ripgrep, fd, bat, eza, fzf, jq, git, etc.
#   - Dev tools layer: neovim, nodejs, uv, bun, etc.
#   - Service layers: Tailscale, code-server, Zed remote
#
# Constitution alignment:
#   - Principle I: Declarative Configuration (container defined in Nix)
#   - Principle II: Headless-First Design (CLI-based, no GUI)
#   - Principle III: Security by Default (minimal image, no root)
#   - Principle IV: Modular and Reusable (layered for caching)

{
  pkgs,
  lib ? pkgs.lib,
  ...
}:

let
  # ─────────────────────────────────────────────────────────────────────────────
  # Package Collections
  # ─────────────────────────────────────────────────────────────────────────────
  # These mirror the packages from home/modules/*.nix for consistency

  # Base system utilities
  basePackages = with pkgs; [
    coreutils
    bash
    shadow # useradd, usermod, etc.
    su # For user switching
    util-linux # Basic system utilities
    gnugrep
    gnused
    gawk
    findutils
    procps # ps, top, etc.
    iproute2 # ip, ss, etc.
    iputils # ping
    netcat-gnu
    cacert # SSL certificates
    tzdata # Timezone data
  ];

  # CLI tools (from home/modules/cli.nix)
  cliPackages = with pkgs; [
    curl
    wget
    htop
    jq
    tree
    ripgrep
    fd
    yazi
    btop
    ncdu
    just
    fzf
    bat
    eza
    less
    direnv
    nix-direnv
  ];

  # Git and version control (from home/modules/git.nix)
  gitPackages = with pkgs; [
    git
    gh
    lazygit
  ];

  # Development tools (from home/modules/dev.nix)
  # Note: Some packages like claude-code, terraform require unfree
  devPackages = with pkgs; [
    # Editors
    neovim

    # Terminal multiplexers
    zellij
    tmux

    # AI tools (unfree packages commented - consumers can add via overlay)
    # opencode
    # claude-code
    # goose-cli

    # Runtimes and package managers
    nodejs
    bun
    uv

    # Rust toolchain
    rustc
    cargo
    rustfmt
    clippy

    # 1Password CLI for secrets (unfree - add via overlay if needed)
    # _1password-cli
  ];

  # Fish shell
  fishPackages = with pkgs; [
    fish
    fishPlugins.fzf-fish
    fishPlugins.done
  ];

  # Tailscale for networking
  tailscalePackages = with pkgs; [
    tailscale
    iptables # Required for some Tailscale features
  ];

  # code-server for browser-based IDE
  codeServerPackages = with pkgs; [
    code-server
  ];

  # SSH server for Tailscale SSH fallback
  sshPackages = with pkgs; [
    openssh
  ];

  # Syncthing for optional file sync
  syncthingPackages = with pkgs; [
    syncthing
  ];

  # All packages combined
  allPackages =
    basePackages
    ++ cliPackages
    ++ gitPackages
    ++ devPackages
    ++ fishPackages
    ++ tailscalePackages
    ++ codeServerPackages
    ++ sshPackages
    ++ syncthingPackages;

  # ─────────────────────────────────────────────────────────────────────────────
  # Container User Setup
  # ─────────────────────────────────────────────────────────────────────────────

  # User ID for the dev user (matches common container conventions)
  devUid = 1000;
  devGid = 1000;

  # Create passwd and group files for the dev user
  passwdContents = ''
    root:x:0:0:root:/root:/bin/bash
    dev:x:${toString devUid}:${toString devGid}:Developer:/home/dev:/run/current-system/sw/bin/fish
    nobody:x:65534:65534:Unprivileged:/var/empty:/bin/false
  '';

  groupContents = ''
    root:x:0:
    dev:x:${toString devGid}:dev
    wheel:x:10:dev
    nobody:x:65534:
  '';

  shadowContents = ''
    root:!:1::::::
    dev:!:1::::::
    nobody:!:1::::::
  '';

  # ─────────────────────────────────────────────────────────────────────────────
  # Configuration Files
  # ─────────────────────────────────────────────────────────────────────────────

  # Fish shell configuration
  fishConfig = pkgs.writeText "config.fish" ''
    # Nix environment
    set -gx NIX_SSL_CERT_FILE /etc/ssl/certs/ca-bundle.crt
    set -gx SSL_CERT_FILE /etc/ssl/certs/ca-bundle.crt

    # Path
    set -gx PATH /run/current-system/sw/bin $PATH

    # Aliases (matching home/modules/fish.nix)
    alias cat='bat'
    alias ls='eza'
    alias ll='eza -la'
    alias la='eza -a'
    alias lt='eza --tree'
    alias grep='rg'
    alias find='fd'

    # Editor
    set -gx EDITOR nvim
    set -gx VISUAL nvim

    # Greeting
    function fish_greeting
      echo "🐟 Dev Container Ready"
      echo "   SSH: ssh dev@\$HOSTNAME"
      echo "   code-server: http://\$HOSTNAME:8080"
    end
  '';

  # Git global configuration
  gitConfig = pkgs.writeText "gitconfig" ''
    [init]
    defaultBranch = main

    [pull]
    rebase = true

    [push]
    autoSetupRemote = true

    [diff]
    algorithm = histogram

    [merge]
    conflictstyle = diff3

    [fetch]
    prune = true

    [color]
    ui = auto

    [credential]
    helper = !${pkgs.gh}/bin/gh auth git-credential
  '';

  # Neovim basic configuration
  nvimConfig = pkgs.writeText "init.vim" ''
    " Basic sensible defaults
    set number
    set relativenumber
    set expandtab
    set tabstop=2
    set shiftwidth=2
    set autoindent
    set smartindent
    set mouse=a
    set clipboard=unnamedplus
  '';

  # code-server configuration (default - will be overridden at runtime if Tailscale unavailable)
  # When Tailscale is connected, we bind to 0.0.0.0 (Tailscale handles auth)
  # When Tailscale fails, we bind to 127.0.0.1 for security
  codeServerConfigTailscale = pkgs.writeText "code-server-config-tailscale.yaml" ''
    bind-addr: 0.0.0.0:8080
    auth: none
    cert: false
  '';

  codeServerConfigLocal = pkgs.writeText "code-server-config-local.yaml" ''
    bind-addr: 127.0.0.1:8080
    auth: none
    cert: false
  '';

  # ─────────────────────────────────────────────────────────────────────────────
  # Entrypoint Script
  # ─────────────────────────────────────────────────────────────────────────────

  entrypoint = pkgs.writeShellScript "entrypoint.sh" ''
    #!/bin/bash
    set -euo pipefail

    # ─────────────────────────────────────────────────────────────────────────
    # Environment Setup
    # ─────────────────────────────────────────────────────────────────────────

    export PATH="/run/current-system/sw/bin:$PATH"
    export HOME="/home/dev"
    export USER="dev"

    # SSL certificates
    export NIX_SSL_CERT_FILE="/etc/ssl/certs/ca-bundle.crt"
    export SSL_CERT_FILE="/etc/ssl/certs/ca-bundle.crt"

    # Container name (passed via environment)
    CONTAINER_NAME="''${CONTAINER_NAME:-devcontainer}"

    # Tailscale auth key (read from secret file for security, not env var)
    TS_AUTHKEY_FILE="''${TS_AUTHKEY_FILE:-/run/secrets/ts_authkey}"
    if [[ -f "$TS_AUTHKEY_FILE" ]]; then
      TS_AUTHKEY=$(cat "$TS_AUTHKEY_FILE")
    else
      TS_AUTHKEY=""
    fi

    # Tailscale tags (passed via environment)
    TS_TAGS="''${TS_TAGS:-tag:devcontainer}"

    # Syncthing enabled flag
    SYNCTHING_ENABLED="''${SYNCTHING_ENABLED:-false}"

    echo "[entrypoint] Starting dev container: $CONTAINER_NAME"

    # ─────────────────────────────────────────────────────────────────────────
    # Directory Setup
    # ─────────────────────────────────────────────────────────────────────────

    # Ensure home directory exists with correct permissions
    mkdir -p /home/dev
    chown -R dev:dev /home/dev 2>/dev/null || true

    # Create runtime directories
    mkdir -p /var/run/tailscale
    mkdir -p /var/lib/tailscale

    # ─────────────────────────────────────────────────────────────────────────
    # Tailscale Setup
    # ─────────────────────────────────────────────────────────────────────────

    if [[ -z "$TS_AUTHKEY" ]]; then
      echo "[entrypoint] WARNING: No Tailscale auth key found" >&2
      echo "[entrypoint] Expected auth key at: $TS_AUTHKEY_FILE" >&2
      echo "[entrypoint] Container will not be accessible via Tailscale" >&2
      TAILSCALE_CONNECTED=false
    else
      echo "[entrypoint] Starting Tailscale daemon (userspace networking)..."

      # Start tailscaled in userspace mode (no TUN device needed)
      tailscaled --tun=userspace-networking \
        --statedir=/var/lib/tailscale \
        --socket=/var/run/tailscale/tailscaled.sock &
      TAILSCALED_PID=$!

      # Wait for socket to be ready
      for i in {1..30}; do
        if [[ -S /var/run/tailscale/tailscaled.sock ]]; then
          break
        fi
        sleep 0.5
      done

      # Authenticate and connect
      echo "[entrypoint] Connecting to Tailscale as $CONTAINER_NAME..."
      if tailscale --socket=/var/run/tailscale/tailscaled.sock up \
        --authkey="$TS_AUTHKEY" \
        --hostname="$CONTAINER_NAME" \
        --advertise-tags="$TS_TAGS" \
        --ssh \
        --accept-routes=false \
        --accept-dns=false; then
        echo "[entrypoint] Tailscale connected"
        tailscale --socket=/var/run/tailscale/tailscaled.sock status
        TAILSCALE_CONNECTED=true
      else
        echo "[entrypoint] ERROR: Tailscale authentication failed" >&2
        echo "[entrypoint] Check that TS_AUTHKEY is valid and not expired" >&2
        echo "[entrypoint] Container will only be accessible via direct port exposure" >&2
        TAILSCALE_CONNECTED=false
      fi
    fi

    # ─────────────────────────────────────────────────────────────────────────
    # code-server Setup
    # ─────────────────────────────────────────────────────────────────────────

    # Create code-server directories
    mkdir -p /home/dev/.config/code-server
    mkdir -p /home/dev/.local/share/code-server

    # Select config based on Tailscale status
    # If Tailscale connected: bind to 0.0.0.0 (Tailscale ACLs handle auth)
    # If Tailscale failed: bind to 127.0.0.1 for security (local access only)
    if [[ "''${TAILSCALE_CONNECTED:-false}" == "true" ]]; then
      echo "[entrypoint] Starting code-server on 0.0.0.0:8080 (Tailscale provides auth)..."
      cp /etc/code-server/config-tailscale.yaml /home/dev/.config/code-server/config.yaml
    else
      echo "[entrypoint] WARNING: Starting code-server on 127.0.0.1:8080 (Tailscale unavailable)" >&2
      echo "[entrypoint] code-server only accessible from within container" >&2
      cp /etc/code-server/config-local.yaml /home/dev/.config/code-server/config.yaml
    fi
    chown dev:dev /home/dev/.config/code-server/config.yaml

    # Start code-server as dev user
    su -s /bin/bash dev -c "code-server --config /home/dev/.config/code-server/config.yaml /home/dev" &
    CODE_SERVER_PID=$!

    # ─────────────────────────────────────────────────────────────────────────
    # Syncthing Setup (Optional)
    # ─────────────────────────────────────────────────────────────────────────

    if [[ "$SYNCTHING_ENABLED" == "true" ]]; then
      echo "[entrypoint] Starting Syncthing..."

      # Create sync directory
      mkdir -p /home/dev/sync
      chown dev:dev /home/dev/sync

      # Create syncthing config directory
      mkdir -p /home/dev/.config/syncthing
      chown -R dev:dev /home/dev/.config/syncthing

      # Start syncthing as dev user
      # GUI on 8384, sync on 22000
      su -s /bin/bash dev -c "syncthing --no-browser --gui-address=0.0.0.0:8384 --home=/home/dev/.config/syncthing" &
      SYNCTHING_PID=$!

      echo "[entrypoint] Syncthing GUI available at http://$CONTAINER_NAME:8384"
    fi

    # ─────────────────────────────────────────────────────────────────────────
    # Ready Message
    # ─────────────────────────────────────────────────────────────────────────

    echo ""
    echo "=========================================="
    echo " Dev Container Ready: $CONTAINER_NAME"
    echo "=========================================="
    echo ""
    echo " SSH:          ssh dev@$CONTAINER_NAME"
    echo " code-server:  http://$CONTAINER_NAME:8080"
    if [[ "$SYNCTHING_ENABLED" == "true" ]]; then
      echo " Syncthing:    http://$CONTAINER_NAME:8384"
    fi
    echo ""
    echo "=========================================="
    echo ""

    # ─────────────────────────────────────────────────────────────────────────
    # Keep Container Running
    # ─────────────────────────────────────────────────────────────────────────

    # Wait for any process to exit
    wait -n

    # If we get here, something crashed - exit with error
    echo "[entrypoint] A process exited unexpectedly"
    exit 1
  '';

  # ─────────────────────────────────────────────────────────────────────────────
  # Container Image Definition
  # ─────────────────────────────────────────────────────────────────────────────

in
pkgs.dockerTools.buildLayeredImage {
  name = "devcontainer";
  tag = "latest";

  # Layer contents for better caching
  # Each array element becomes a separate layer
  contents = [
    # Layer 1: Base system
    (pkgs.buildEnv {
      name = "base-env";
      paths = basePackages;
      pathsToLink = [
        "/bin"
        "/lib"
        "/share"
        "/etc"
      ];
    })

    # Layer 2: CLI tools
    (pkgs.buildEnv {
      name = "cli-env";
      paths = cliPackages ++ gitPackages;
      pathsToLink = [
        "/bin"
        "/lib"
        "/share"
      ];
    })

    # Layer 3: Development tools
    (pkgs.buildEnv {
      name = "dev-env";
      paths = devPackages ++ fishPackages;
      pathsToLink = [
        "/bin"
        "/lib"
        "/share"
      ];
    })

    # Layer 4: Services (Tailscale, code-server, SSH, Syncthing)
    (pkgs.buildEnv {
      name = "services-env";
      paths = tailscalePackages ++ codeServerPackages ++ sshPackages ++ syncthingPackages;
      pathsToLink = [
        "/bin"
        "/lib"
        "/share"
      ];
    })
  ];

  # Extra commands to run during image build
  extraCommands = ''
    # Create directory structure
    mkdir -p tmp var/run var/lib var/empty var/log
    mkdir -p home/dev/.config home/dev/.local/share home/dev/sync
    mkdir -p etc/ssl/certs run/current-system/sw/bin

    # Create symlinks to package binaries
    # This makes /run/current-system/sw/bin work like NixOS
    for pkg in ${lib.concatStringsSep " " allPackages}; do
      if [ -d "$pkg/bin" ]; then
        for bin in "$pkg/bin"/*; do
          if [ -f "$bin" ]; then
            ln -sf "$bin" run/current-system/sw/bin/ || true
          fi
        done
      fi
    done

    # Copy SSL certificates
    cp -r ${pkgs.cacert}/etc/ssl/certs/* etc/ssl/certs/ || true

    # Create passwd/group/shadow files
    echo '${passwdContents}' > etc/passwd
    echo '${groupContents}' > etc/group
    echo '${shadowContents}' > etc/shadow
    chmod 644 etc/passwd etc/group
    chmod 640 etc/shadow

    # Create nsswitch.conf for name resolution
    cat > etc/nsswitch.conf <<EOF
    passwd: files
    group: files
    shadow: files
    hosts: files dns
    networks: files
    EOF

    # Fish configuration
    mkdir -p home/dev/.config/fish
    cp ${fishConfig} home/dev/.config/fish/config.fish

    # Git configuration
    cp ${gitConfig} home/dev/.gitconfig

    # Neovim configuration
    mkdir -p home/dev/.config/nvim
    cp ${nvimConfig} home/dev/.config/nvim/init.vim

    # code-server configuration (two variants based on Tailscale status)
    mkdir -p etc/code-server
    cp ${codeServerConfigTailscale} etc/code-server/config-tailscale.yaml
    cp ${codeServerConfigLocal} etc/code-server/config-local.yaml

    # Set ownership (will be fixed at runtime)
    # Note: dockerTools doesn't support chown during build
  '';

  # Container configuration
  config = {
    # Default command
    Cmd = [ "${entrypoint}" ];

    # Working directory
    WorkingDir = "/home/dev";

    # Default user (run as root initially for setup, then drops to dev)
    User = "0:0";

    # Environment variables
    Env = [
      "PATH=/run/current-system/sw/bin:/bin"
      "HOME=/home/dev"
      "USER=dev"
      "SHELL=/run/current-system/sw/bin/fish"
      "TERM=xterm-256color"
      "LANG=en_US.UTF-8"
      "LC_ALL=en_US.UTF-8"
      "NIX_SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
      "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
    ];

    # Exposed ports
    ExposedPorts = {
      "8080/tcp" = { }; # code-server
      "8384/tcp" = { }; # Syncthing GUI (optional)
      "22000/tcp" = { }; # Syncthing sync (optional)
    };

    # Labels
    Labels = {
      "org.opencontainers.image.title" = "nix-devbox devcontainer";
      "org.opencontainers.image.description" =
        "Development container with CLI tools, Tailscale, and code-server";
      "org.opencontainers.image.source" = "https://github.com/colebateman/nix-devbox";
    };

    # Volumes
    Volumes = {
      "/home/dev" = { };
      "/var/lib/tailscale" = { };
    };
  };

  # Maximum number of layers (for caching efficiency)
  maxLayers = 10;
}
