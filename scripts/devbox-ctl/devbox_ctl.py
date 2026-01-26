#!/usr/bin/env python3
"""
devbox-ctl - Container management CLI for the nix-devbox orchestrator.

This tool manages dev containers on the orchestrator host, providing:
  - Container lifecycle operations (create, start, stop, destroy)
  - 1Password integration for Tailscale auth key retrieval
  - Container registry tracking
  - Resource limit enforcement

Constitution alignment:
  - Principle II: Headless-First Design (CLI-based management)
  - Principle III: Security by Default (validates inputs, secure secrets)
  - Principle V: Documentation as Code (comprehensive help)
"""

import fcntl
import json
import os
import pwd
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

# click is provided by Nix at runtime; type: ignore comments suppress LSP false positives
import click  # type: ignore[import-untyped,import-not-found]

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────

VERSION = "1.0.0"

# Data directory for devbox-ctl state
DATA_DIR = Path(os.environ.get("DEVBOX_DATA_DIR", Path.home() / ".local/share/devbox"))
REGISTRY_FILE = DATA_DIR / "containers.json"

# Configuration from environment (set by NixOS module from users.nix)
OP_VAULT = os.environ.get("DEVBOX_OP_VAULT", "DevBox")
MAX_PER_USER = int(os.environ.get("DEVBOX_MAX_PER_USER", "5"))
MAX_GLOBAL = int(os.environ.get("DEVBOX_MAX_GLOBAL", "7"))
DEFAULT_CPU = int(os.environ.get("DEVBOX_DEFAULT_CPU", "2"))
DEFAULT_MEMORY = os.environ.get("DEVBOX_DEFAULT_MEMORY", "4G")
IDLE_STOP_DAYS = int(os.environ.get("DEVBOX_IDLE_STOP_DAYS", "7"))
STOPPED_DESTROY_DAYS = int(os.environ.get("DEVBOX_STOPPED_DESTROY_DAYS", "14"))

# Container image name
CONTAINER_IMAGE = os.environ.get(
    "DEVBOX_CONTAINER_IMAGE", "localhost/devcontainer:latest"
)


# ─────────────────────────────────────────────────────────────────────────────
# Exceptions
# ─────────────────────────────────────────────────────────────────────────────


class DevboxError(Exception):
    """Base exception for devbox-ctl errors."""

    def __init__(self, message: str, detail: str = "", suggestion: str = ""):
        self.message = message
        self.detail = detail
        self.suggestion = suggestion
        super().__init__(message)


class ValidationError(DevboxError):
    """Raised when validation fails."""

    pass


class NotFoundError(DevboxError):
    """Raised when a container is not found."""

    pass


class DevboxPermissionError(DevboxError):
    """Raised when user lacks permission."""

    pass


class SecretError(DevboxError):
    """Raised when secret retrieval fails."""

    pass


class PodmanError(DevboxError):
    """Raised when Podman operations fail."""

    pass


# ─────────────────────────────────────────────────────────────────────────────
# Utilities
# ─────────────────────────────────────────────────────────────────────────────


def get_current_user() -> str:
    """Get the current username.

    Prefers $USER environment variable, falls back to passwd database.
    This works reliably in cron, systemd services, and remote execution
    where os.getlogin() would fail.
    """
    return os.environ.get("USER") or pwd.getpwuid(os.getuid()).pw_name


def get_timestamp() -> str:
    """Get current UTC timestamp in ISO format."""
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def run_command(
    cmd: list[str], capture: bool = True, check: bool = True
) -> subprocess.CompletedProcess:
    """Run a command and return the result."""
    return subprocess.run(
        cmd,
        capture_output=capture,
        text=True,
        check=check,
    )


def is_admin(user: str) -> bool:
    """Check if user is in wheel/sudo group."""
    try:
        result = run_command(["groups", user], check=False)
        groups = result.stdout.strip().split()
        return "wheel" in groups or "sudo" in groups
    except Exception:
        return False


# ─────────────────────────────────────────────────────────────────────────────
# Validation
# ─────────────────────────────────────────────────────────────────────────────

# Container name pattern: 3-63 chars, starts with letter, alphanumeric + hyphens
NAME_PATTERN = re.compile(r"^[a-z][a-z0-9-]{1,61}[a-z0-9]$")


def validate_container_name(name: str) -> None:
    """Validate container name format."""
    if len(name) < 3:
        raise ValidationError(
            f"Container name too short: {name}",
            "Container names must be at least 3 characters.",
            "Example: devbox-ctl create my-project",
        )

    if len(name) > 63:
        raise ValidationError(
            f"Container name too long: {name}",
            "Container names must be at most 63 characters.",
        )

    if not NAME_PATTERN.match(name):
        raise ValidationError(
            f"Invalid container name: {name}",
            "Names must start with a letter, end with alphanumeric, "
            "and contain only lowercase letters, digits, and hyphens.",
            "Example: my-project, dev-env-1",
        )

    if "--" in name:
        raise ValidationError(
            f"Invalid container name: {name}",
            "Container names cannot contain consecutive hyphens.",
        )


def validate_memory(memory: str) -> None:
    """Validate memory format (e.g., 4G, 512M)."""
    if not re.match(r"^\d+[MG]$", memory):
        raise ValidationError(
            f"Invalid memory format: {memory}",
            "Memory must be a number followed by M or G.",
            "Example: --memory 4G or --memory 512M",
        )


def validate_cpu(cpu: int) -> None:
    """Validate CPU limit."""
    if cpu < 1 or cpu > 64:
        raise ValidationError(
            f"Invalid CPU limit: {cpu}",
            "CPU must be between 1 and 64.",
        )


# ─────────────────────────────────────────────────────────────────────────────
# Registry Management
# ─────────────────────────────────────────────────────────────────────────────


def init_registry() -> None:
    """Initialize the registry file if it doesn't exist.

    Uses atomic file creation (O_CREAT | O_EXCL) to prevent TOCTOU race conditions.
    """
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    try:
        # O_CREAT | O_EXCL ensures atomic creation - fails if file exists
        fd = os.open(REGISTRY_FILE, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o644)
        with os.fdopen(fd, "w") as f:
            fcntl.flock(f.fileno(), fcntl.LOCK_EX)
            try:
                json.dump({"version": 1, "containers": []}, f, indent=2)
            finally:
                fcntl.flock(f.fileno(), fcntl.LOCK_UN)
    except FileExistsError:
        pass  # File already exists, nothing to do


def load_registry() -> dict:
    """Load the container registry with shared file locking.

    Uses shared lock to allow concurrent reads while preventing
    reads during writes.
    """
    init_registry()
    with open(REGISTRY_FILE, "r") as f:
        fcntl.flock(f.fileno(), fcntl.LOCK_SH)
        try:
            return json.load(f)
        finally:
            fcntl.flock(f.fileno(), fcntl.LOCK_UN)


def save_registry(registry: dict) -> None:
    """Save the container registry with exclusive file locking.

    Uses exclusive lock to prevent concurrent modifications and
    ensure atomic writes.
    """
    with open(REGISTRY_FILE, "w") as f:
        fcntl.flock(f.fileno(), fcntl.LOCK_EX)
        try:
            json.dump(registry, f, indent=2)
        finally:
            fcntl.flock(f.fileno(), fcntl.LOCK_UN)


def get_container(name: str) -> Optional[dict]:
    """Get a container by name."""
    registry = load_registry()
    for container in registry["containers"]:
        if container["name"] == name:
            return container
    return None


def container_exists(name: str) -> bool:
    """Check if a container exists."""
    return get_container(name) is not None


def add_container(
    name: str,
    owner: str,
    cpu: int,
    memory: str,
    with_syncthing: bool = False,
) -> None:
    """Add a container to the registry.

    Uses exclusive file locking across the entire read-modify-write cycle
    to prevent lost-update race conditions.
    """
    init_registry()
    with open(REGISTRY_FILE, "r+") as f:
        fcntl.flock(f.fileno(), fcntl.LOCK_EX)
        try:
            registry = json.load(f)
            timestamp = get_timestamp()

            registry["containers"].append(
                {
                    "name": name,
                    "owner": owner,
                    "state": "creating",
                    "createdAt": timestamp,
                    "lastActivityAt": timestamp,
                    "cpuLimit": cpu,
                    "memoryLimit": memory,
                    "volumeName": f"{name}-data",
                    "tailscaleHostname": name,
                    "tailscaleIP": None,
                    "withSyncthing": with_syncthing,
                }
            )
            f.seek(0)
            f.truncate()
            json.dump(registry, f, indent=2)
        finally:
            fcntl.flock(f.fileno(), fcntl.LOCK_UN)


def update_container(name: str, **updates) -> None:
    """Update container fields in the registry.

    Uses exclusive file locking across the entire read-modify-write cycle
    to prevent lost-update race conditions.
    """
    init_registry()
    with open(REGISTRY_FILE, "r+") as f:
        fcntl.flock(f.fileno(), fcntl.LOCK_EX)
        try:
            registry = json.load(f)
            for container in registry["containers"]:
                if container["name"] == name:
                    container.update(updates)
                    break
            f.seek(0)
            f.truncate()
            json.dump(registry, f, indent=2)
        finally:
            fcntl.flock(f.fileno(), fcntl.LOCK_UN)


def remove_container(name: str) -> None:
    """Remove a container from the registry.

    Uses exclusive file locking across the entire read-modify-write cycle
    to prevent lost-update race conditions.
    """
    init_registry()
    with open(REGISTRY_FILE, "r+") as f:
        fcntl.flock(f.fileno(), fcntl.LOCK_EX)
        try:
            registry = json.load(f)
            registry["containers"] = [
                c for c in registry["containers"] if c["name"] != name
            ]
            f.seek(0)
            f.truncate()
            json.dump(registry, f, indent=2)
        finally:
            fcntl.flock(f.fileno(), fcntl.LOCK_UN)


def count_user_containers(user: str) -> int:
    """Count containers owned by a user."""
    registry = load_registry()
    return sum(1 for c in registry["containers"] if c["owner"] == user)


def count_all_containers() -> int:
    """Count all containers."""
    registry = load_registry()
    return len(registry["containers"])


def get_user_containers(user: str) -> list[dict]:
    """Get all containers owned by a user."""
    registry = load_registry()
    return [c for c in registry["containers"] if c["owner"] == user]


def get_all_containers() -> list[dict]:
    """Get all containers."""
    registry = load_registry()
    return registry["containers"]


# ─────────────────────────────────────────────────────────────────────────────
# 1Password Integration
# ─────────────────────────────────────────────────────────────────────────────


def check_op_cli() -> None:
    """Verify 1Password CLI is available."""
    try:
        run_command(["op", "--version"])
    except FileNotFoundError:
        raise SecretError(
            "1Password CLI not found",
            "The 'op' command is required for secret retrieval.",
            "Ensure the orchestrator module is enabled.",
        )


def check_op_auth() -> None:
    """Verify 1Password authentication is working."""
    if not os.environ.get("OP_SERVICE_ACCOUNT_TOKEN"):
        raise SecretError(
            "1Password Service Account not configured",
            "OP_SERVICE_ACCOUNT_TOKEN environment variable is not set.",
            "Configure via systemd credential or agenix. See quickstart.md.",
        )

    try:
        run_command(["op", "vault", "list", "--format=json"])
    except subprocess.CalledProcessError:
        raise SecretError(
            "1Password authentication failed",
            "Unable to authenticate with the Service Account token.",
            "Verify OP_SERVICE_ACCOUNT_TOKEN is valid.",
        )


def get_tailscale_authkey(username: str) -> str:
    """Retrieve Tailscale auth key from 1Password."""
    check_op_cli()
    check_op_auth()

    item_name = f"{username}-tailscale-authkey"
    reference = f"op://{OP_VAULT}/{item_name}/password"

    try:
        result = run_command(["op", "read", reference, "--no-newline"])
        authkey = result.stdout
    except subprocess.CalledProcessError:
        raise SecretError(
            "Failed to retrieve Tailscale auth key",
            f"Could not read item '{item_name}' from vault '{OP_VAULT}'.",
            f"Create an item named '{item_name}' with the auth key in the 'password' field.",
        )

    if not authkey:
        raise SecretError(
            "Tailscale auth key is empty",
            f"The auth key for user '{username}' exists but has no value.",
        )

    if not authkey.startswith("tskey-"):
        raise SecretError(
            "Invalid Tailscale auth key format",
            "The retrieved key does not appear to be a valid Tailscale auth key.",
            "Tailscale auth keys should start with 'tskey-'.",
        )

    return authkey


def get_tailscale_tags(username: str) -> str:
    """Generate Tailscale tags for a container."""
    return f"tag:devcontainer,tag:{username}-container"


# ─────────────────────────────────────────────────────────────────────────────
# Podman Operations
# ─────────────────────────────────────────────────────────────────────────────


def check_podman() -> None:
    """Verify Podman is available."""
    try:
        run_command(["podman", "--version"])
    except FileNotFoundError:
        raise PodmanError(
            "Podman not found",
            "Podman is required for container management.",
            "Ensure the orchestrator module is enabled.",
        )


def podman_volume_exists(name: str) -> bool:
    """Check if a Podman volume exists."""
    result = run_command(["podman", "volume", "exists", name], check=False)
    return result.returncode == 0


def podman_create_volume(name: str) -> None:
    """Create a Podman volume."""
    run_command(["podman", "volume", "create", name])


def podman_remove_volume(name: str) -> None:
    """Remove a Podman volume."""
    run_command(["podman", "volume", "rm", name], check=False)


def podman_container_exists(name: str) -> bool:
    """Check if a Podman container exists."""
    result = run_command(["podman", "container", "exists", name], check=False)
    return result.returncode == 0


def podman_container_state(name: str) -> Optional[str]:
    """Get the state of a Podman container."""
    if not podman_container_exists(name):
        return None
    result = run_command(
        ["podman", "inspect", "--format", "{{.State.Status}}", name], check=False
    )
    return result.stdout.strip() if result.returncode == 0 else None


def podman_start_container(name: str) -> None:
    """Start a Podman container."""
    try:
        run_command(["podman", "start", name])
    except subprocess.CalledProcessError as e:
        raise PodmanError(
            f"Failed to start container: {name}",
            e.stderr or str(e),
        )


def podman_stop_container(name: str) -> None:
    """Stop a Podman container."""
    try:
        run_command(["podman", "stop", name])
    except subprocess.CalledProcessError as e:
        raise PodmanError(
            f"Failed to stop container: {name}",
            e.stderr or str(e),
        )


def podman_remove_container(name: str, force: bool = False) -> None:
    """Remove a Podman container."""
    cmd = ["podman", "rm"]
    if force:
        cmd.append("-f")
    cmd.append(name)
    try:
        run_command(cmd)
    except subprocess.CalledProcessError as e:
        raise PodmanError(
            f"Failed to remove container: {name}",
            e.stderr or str(e),
        )


def podman_logs(name: str, follow: bool = False, tail: int = 100) -> None:
    """Stream container logs."""
    cmd = ["podman", "logs"]
    if follow:
        cmd.append("-f")
    cmd.extend(["--tail", str(tail)])
    cmd.append(name)

    # Stream directly to terminal
    subprocess.run(cmd)


def podman_run_container(
    name: str,
    volume: str,
    cpu: int,
    memory: str,
    authkey: str,
    tags: str,
    with_syncthing: bool = False,
) -> None:
    """Run a new container."""
    cmd = [
        "podman",
        "run",
        "-d",
        "--name",
        name,
        "--hostname",
        name,
        # Resource limits
        "--cpus",
        str(cpu),
        "--memory",
        memory,
        # Persistent volume
        "-v",
        f"{volume}:/home/dev:Z",
        # Environment variables for container startup
        "-e",
        f"TS_AUTHKEY={authkey}",
        "-e",
        f"TS_TAGS={tags}",
        "-e",
        f"CONTAINER_NAME={name}",
        "-e",
        f"SYNCTHING_ENABLED={'true' if with_syncthing else 'false'}",
        # Capabilities for Tailscale userspace networking
        "--cap-add=NET_ADMIN",
        # Restart policy
        "--restart=unless-stopped",
        # Container image
        CONTAINER_IMAGE,
    ]

    try:
        run_command(cmd)
    except subprocess.CalledProcessError as e:
        raise PodmanError(
            f"Failed to create container: {name}",
            e.stderr or str(e),
        )


def wait_for_tailscale(name: str, timeout: int = 60) -> Optional[str]:
    """Wait for Tailscale to connect and return the IP."""
    import time

    for _ in range(timeout):
        try:
            result = run_command(
                [
                    "podman",
                    "exec",
                    name,
                    "tailscale",
                    "ip",
                    "-4",
                ],
                check=False,
            )
            if result.returncode == 0 and result.stdout.strip():
                return result.stdout.strip()
        except Exception:
            pass
        time.sleep(1)
    return None


# ─────────────────────────────────────────────────────────────────────────────
# CLI Commands
# ─────────────────────────────────────────────────────────────────────────────


@click.group()
@click.version_option(version=VERSION)
@click.option(
    "--debug", is_flag=True, envvar="DEVBOX_DEBUG", help="Enable debug output"
)
@click.pass_context
def cli(ctx: click.Context, debug: bool) -> None:
    """Container management CLI for the nix-devbox orchestrator."""
    ctx.ensure_object(dict)
    ctx.obj["debug"] = debug


@cli.command()  # type: ignore[attr-defined]
@click.argument("name")
@click.option("--cpu", default=DEFAULT_CPU, help=f"CPU cores (default: {DEFAULT_CPU})")
@click.option(
    "--memory", default=DEFAULT_MEMORY, help=f"Memory limit (default: {DEFAULT_MEMORY})"
)
@click.option("--no-start", is_flag=True, help="Create but don't start")
@click.option("--with-syncthing", is_flag=True, help="Enable Syncthing for file sync")
@click.pass_context
def create(ctx, name, cpu, memory, no_start, with_syncthing):
    """Create a new dev container."""
    user = get_current_user()

    try:
        # Validation
        click.echo(f"Creating container '{name}'...")
        validate_container_name(name)
        validate_cpu(cpu)
        validate_memory(memory)

        if container_exists(name):
            raise ValidationError(
                f"Container already exists: {name}",
                "A container with this name already exists.",
                "Run 'devbox-ctl list' to see containers, or choose a different name.",
            )

        # Check limits
        user_count = count_user_containers(user)
        if user_count >= MAX_PER_USER:
            raise ValidationError(
                "Container limit reached",
                f"You have {user_count} containers (max: {MAX_PER_USER}).",
                "Run 'devbox-ctl destroy <name>' to remove a container.",
            )

        global_count = count_all_containers()
        if global_count >= MAX_GLOBAL:
            raise ValidationError(
                "Global container limit reached",
                f"The orchestrator has {global_count} containers (max: {MAX_GLOBAL}).",
                "Contact an administrator or wait for cleanup.",
            )

        # Check Podman
        check_podman()

        # Get auth key from 1Password
        click.echo("Retrieving Tailscale auth key from 1Password...")
        authkey = get_tailscale_authkey(user)
        tags = get_tailscale_tags(user)

        # Add to registry (will be cleaned up on failure)
        add_container(name, user, cpu, memory, with_syncthing)

        try:
            # Create volume
            volume_name = f"{name}-data"
            if not podman_volume_exists(volume_name):
                click.echo(f"Creating volume '{volume_name}'...")
                podman_create_volume(volume_name)

            if no_start:
                update_container(name, state="stopped")
                click.echo(
                    click.style(
                        f"✓ Container '{name}' created (not started)", fg="green"
                    )
                )
                return

            # Run container
            click.echo("Starting container...")
            podman_run_container(
                name, volume_name, cpu, memory, authkey, tags, with_syncthing
            )

            # Wait for Tailscale
            click.echo("Waiting for Tailscale connection...")
            ts_ip = wait_for_tailscale(name)

            if ts_ip:
                update_container(name, state="running", tailscaleIP=ts_ip)
                click.echo()
                click.echo(
                    click.style(
                        f"✓ Container '{name}' created successfully!", fg="green"
                    )
                )
                click.echo()
                click.echo(f"Connect via SSH:     ssh dev@{name}")
                click.echo(
                    f"Connect via Zed:     Open Zed → Connect to Server → dev@{name}"
                )
                click.echo(f"Connect via Browser: http://{name}:8080 (code-server)")
                if with_syncthing:
                    click.echo()
                    click.echo("Syncthing enabled:")
                    click.echo(f"  GUI:         http://{name}:8384")
                    click.echo("  Sync folder: /home/dev/sync")
            else:
                update_container(name, state="running")
                click.echo(
                    click.style(
                        "⚠ Container created but Tailscale connection timed out",
                        fg="yellow",
                    )
                )
                click.echo("Check manually with: devbox-ctl status " + name)
        except Exception:
            # Clean up registry entry on failure to prevent orphaned entries
            click.echo(
                click.style("Cleaning up after failure...", fg="yellow"), err=True
            )
            remove_container(name)
            raise

    except DevboxError as e:
        click.echo()
        click.echo(click.style(f"Error: {e.message}", fg="red"), err=True)
        if e.detail:
            click.echo(f"  {e.detail}", err=True)
        if e.suggestion:
            click.echo(f"  {e.suggestion}", err=True)
        sys.exit(1)


@cli.command()  # type: ignore[attr-defined]
@click.option(
    "--all", "show_all", is_flag=True, help="List all containers (admin only)"
)
@click.option("--json", "as_json", is_flag=True, help="Output as JSON")
@click.option(
    "--state",
    type=click.Choice(["running", "stopped", "all"]),
    default="all",
    help="Filter by state",
)
def list(show_all, as_json, state):
    """List your containers."""
    user = get_current_user()

    if show_all:
        if not is_admin(user):
            click.echo(
                click.style("Error: --all requires admin privileges", fg="red"),
                err=True,
            )
            sys.exit(1)
        containers = get_all_containers()
    else:
        containers = get_user_containers(user)

    # Filter by state
    if state != "all":
        containers = [c for c in containers if c["state"] == state]

    if as_json:
        click.echo(json.dumps(containers, indent=2))
        return

    if not containers:
        click.echo("No containers found.")
        return

    # Table header
    click.echo(
        f"{'NAME':<20} {'STATE':<10} {'CREATED':<20} {'TAILSCALE IP':<16}"
        + (" OWNER" if show_all else "")
    )
    click.echo("-" * (66 + (10 if show_all else 0)))

    for c in containers:
        created = c["createdAt"][:10] if c.get("createdAt") else "unknown"
        ts_ip = c.get("tailscaleIP") or "-"
        row = f"{c['name']:<20} {c['state']:<10} {created:<20} {ts_ip:<16}"
        if show_all:
            row += f" {c.get('owner', 'unknown')}"
        click.echo(row)


@cli.command()  # type: ignore[attr-defined]
@click.argument("name")
def start(name: str) -> None:
    """Start a stopped container."""
    user = get_current_user()

    try:
        container = get_container(name)
        if not container:
            raise NotFoundError(
                f"Container not found: {name}",
                "No container with this name exists.",
                "Run 'devbox-ctl list' to see your containers.",
            )

        if container["owner"] != user and not is_admin(user):
            raise DevboxPermissionError(
                "Permission denied",
                f"Container '{name}' belongs to user '{container['owner']}'.",
            )

        if container["state"] == "running":
            click.echo(f"Container '{name}' is already running.")
            return

        check_podman()
        click.echo(f"Starting container '{name}'...")
        podman_start_container(name)

        # Wait for Tailscale
        ts_ip = wait_for_tailscale(name, timeout=30)
        update_container(
            name, state="running", tailscaleIP=ts_ip, lastActivityAt=get_timestamp()
        )

        click.echo(click.style(f"✓ Container '{name}' started", fg="green"))
        if ts_ip:
            click.echo(f"  Tailscale IP: {ts_ip}")

    except DevboxError as e:
        click.echo(click.style(f"Error: {e.message}", fg="red"), err=True)
        if e.detail:
            click.echo(f"  {e.detail}", err=True)
        sys.exit(1)


@cli.command()  # type: ignore[attr-defined]
@click.argument("name")
def stop(name: str) -> None:
    """Stop a running container."""
    user = get_current_user()

    try:
        container = get_container(name)
        if not container:
            raise NotFoundError(
                f"Container not found: {name}",
                "No container with this name exists.",
                "Run 'devbox-ctl list' to see your containers.",
            )

        if container["owner"] != user and not is_admin(user):
            raise DevboxPermissionError(
                "Permission denied",
                f"Container '{name}' belongs to user '{container['owner']}'.",
            )

        if container["state"] == "stopped":
            click.echo(f"Container '{name}' is already stopped.")
            return

        check_podman()
        click.echo(f"Stopping container '{name}'...")
        podman_stop_container(name)
        update_container(name, state="stopped", lastActivityAt=get_timestamp())

        click.echo(click.style(f"✓ Container '{name}' stopped", fg="green"))
        click.echo(f"  Data preserved in volume '{name}-data'")
        click.echo(f"  Run 'devbox-ctl start {name}' to resume")

    except DevboxError as e:
        click.echo(click.style(f"Error: {e.message}", fg="red"), err=True)
        if e.detail:
            click.echo(f"  {e.detail}", err=True)
        sys.exit(1)


@cli.command()  # type: ignore[attr-defined]
@click.argument("name")
@click.option("--force", is_flag=True, help="Skip confirmation")
@click.option("--keep-volume", is_flag=True, help="Preserve data volume")
def destroy(name: str, force: bool, keep_volume: bool) -> None:
    """Permanently remove a container."""
    user = get_current_user()

    try:
        container = get_container(name)
        if not container:
            raise NotFoundError(
                f"Container not found: {name}",
                "No container with this name exists.",
                "Run 'devbox-ctl list' to see your containers.",
            )

        if container["owner"] != user and not is_admin(user):
            raise DevboxPermissionError(
                "Permission denied",
                f"Container '{name}' belongs to user '{container['owner']}'.",
            )

        if not force:
            msg = f"This will permanently delete container '{name}'"
            if not keep_volume:
                msg += " and all its data"
            msg += ". Continue?"
            if not click.confirm(click.style(f"⚠ {msg}", fg="yellow")):
                click.echo("Aborted.")
                return

        check_podman()

        # Stop if running
        if podman_container_state(name) == "running":
            click.echo("Stopping container...")
            podman_stop_container(name)

        # Remove container
        click.echo("Removing container...")
        if podman_container_exists(name):
            podman_remove_container(name, force=True)

        # Remove volume (unless --keep-volume)
        volume_name = f"{name}-data"
        if not keep_volume:
            click.echo("Removing volume...")
            podman_remove_volume(volume_name)

        # Remove from registry
        remove_container(name)

        click.echo(click.style(f"✓ Container '{name}' destroyed", fg="green"))
        if keep_volume:
            click.echo(f"  Volume '{volume_name}' preserved")

    except DevboxError as e:
        click.echo(click.style(f"Error: {e.message}", fg="red"), err=True)
        if e.detail:
            click.echo(f"  {e.detail}", err=True)
        sys.exit(1)


@cli.command()  # type: ignore[attr-defined]
@click.argument("name")
def status(name: str) -> None:
    """Show detailed container status."""
    user = get_current_user()

    try:
        container = get_container(name)
        if not container:
            raise NotFoundError(
                f"Container not found: {name}",
                "No container with this name exists.",
                "Run 'devbox-ctl list' to see your containers.",
            )

        if container["owner"] != user and not is_admin(user):
            raise DevboxPermissionError(
                "Permission denied",
                f"Container '{name}' belongs to user '{container['owner']}'.",
            )

        # Get actual Podman state
        podman_state = podman_container_state(name) or "not found"

        click.echo(f"Container: {name}")
        click.echo(f"State:     {container['state']} (podman: {podman_state})")
        click.echo(f"Owner:     {container['owner']}")
        click.echo(f"Created:   {container.get('createdAt', 'unknown')}")
        click.echo(f"Activity:  {container.get('lastActivityAt', 'unknown')}")
        click.echo()
        click.echo("Resources:")
        click.echo(f"  CPU:     {container.get('cpuLimit', DEFAULT_CPU)} cores")
        click.echo(f"  Memory:  {container.get('memoryLimit', DEFAULT_MEMORY)}")
        click.echo(f"  Volume:  {container.get('volumeName', name + '-data')}")
        click.echo()
        click.echo("Network:")
        click.echo(
            f"  Tailscale IP:   {container.get('tailscaleIP') or 'not connected'}"
        )
        click.echo(f"  Tailscale Name: {container.get('tailscaleHostname', name)}")
        click.echo()
        click.echo("Access:")
        click.echo(f"  SSH:         ssh dev@{name}")
        click.echo(f"  code-server: http://{name}:8080")
        click.echo(f"  Zed:         Connect to Server → dev@{name}")
        if container.get("withSyncthing"):
            click.echo()
            click.echo("Syncthing:")
            click.echo(f"  GUI:         http://{name}:8384")
            click.echo("  Sync folder: /home/dev/sync")

    except DevboxError as e:
        click.echo(click.style(f"Error: {e.message}", fg="red"), err=True)
        if e.detail:
            click.echo(f"  {e.detail}", err=True)
        sys.exit(1)


@cli.command()  # type: ignore[attr-defined]
@click.argument("name")
@click.option("-f", "--follow", is_flag=True, help="Follow log output")
@click.option("--tail", default=100, help="Number of lines to show")
def logs(name: str, follow: bool, tail: int) -> None:
    """View container logs."""
    user = get_current_user()

    try:
        container = get_container(name)
        if not container:
            raise NotFoundError(
                f"Container not found: {name}",
                "No container with this name exists.",
                "Run 'devbox-ctl list' to see your containers.",
            )

        if container["owner"] != user and not is_admin(user):
            raise DevboxPermissionError(
                "Permission denied",
                f"Container '{name}' belongs to user '{container['owner']}'.",
            )

        check_podman()
        podman_logs(name, follow=follow, tail=tail)

    except DevboxError as e:
        click.echo(click.style(f"Error: {e.message}", fg="red"), err=True)
        if e.detail:
            click.echo(f"  {e.detail}", err=True)
        sys.exit(1)


@cli.command("rotate-key")  # type: ignore[attr-defined]
@click.argument("name")
def rotate_key(name: str) -> None:
    """Rotate Tailscale auth key without recreating container."""
    user = get_current_user()

    try:
        container = get_container(name)
        if not container:
            raise NotFoundError(
                f"Container not found: {name}",
                "No container with this name exists.",
                "Run 'devbox-ctl list' to see your containers.",
            )

        if container["owner"] != user and not is_admin(user):
            raise DevboxPermissionError(
                "Permission denied",
                f"Container '{name}' belongs to user '{container['owner']}'.",
            )

        if container["state"] != "running":
            raise ValidationError(
                "Container not running",
                f"Container '{name}' must be running to rotate the auth key.",
                f"Run 'devbox-ctl start {name}' first.",
            )

        check_podman()

        # Get new auth key
        click.echo("Retrieving new Tailscale auth key from 1Password...")
        authkey = get_tailscale_authkey(user)
        tags = get_tailscale_tags(user)

        # Re-authenticate Tailscale inside the container
        click.echo("Rotating Tailscale auth key...")
        try:
            # Logout current session
            run_command(["podman", "exec", name, "tailscale", "logout"], check=False)
            # Re-authenticate with new key
            run_command(
                [
                    "podman",
                    "exec",
                    name,
                    "tailscale",
                    "up",
                    f"--authkey={authkey}",
                    "--ssh",
                    f"--hostname={name}",
                    f"--advertise-tags={tags}",
                ]
            )
        except subprocess.CalledProcessError as e:
            raise PodmanError(
                "Failed to rotate auth key",
                e.stderr or str(e),
            )

        # Update activity timestamp
        update_container(name, lastActivityAt=get_timestamp())

        click.echo(click.style(f"✓ Auth key rotated for '{name}'", fg="green"))

    except DevboxError as e:
        click.echo(click.style(f"Error: {e.message}", fg="red"), err=True)
        if e.detail:
            click.echo(f"  {e.detail}", err=True)
        sys.exit(1)


# ─────────────────────────────────────────────────────────────────────────────
# Entry Point
# ─────────────────────────────────────────────────────────────────────────────


def main() -> None:
    """Main entry point."""
    try:
        cli()  # type: ignore[call-arg]
    except Exception as e:
        click.echo(click.style(f"Unexpected error: {e}", fg="red"), err=True)
        sys.exit(1)


if __name__ == "__main__":
    main()
