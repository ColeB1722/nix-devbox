# SSH Security Module - Hardened SSH Server Configuration
#
# This module configures OpenSSH with maximum hardening for a headless server.
# Password authentication is disabled; only key-based auth is permitted.
#
# Constitution alignment:
#   - Principle III: Security by Default (key-only auth, no root login)
#   - Principle V: Documentation as Code (inline comments)
#
# Security model:
#   - Password authentication: DISABLED (prevents brute force)
#   - Keyboard-interactive auth: DISABLED (prevents PAM bypass)
#   - Root login: DENIED (requires privilege escalation via sudo)
#   - Logging: VERBOSE (audit trail for security review)
#
# Note: Authorized keys are managed via users.users.<name>.openssh.authorizedKeys.keys
# in the user module, NOT via ~/.ssh/authorized_keys files.

{
  config,
  lib,
  pkgs,
  ...
}:

{
  # Security assertions: Enforce SSH hardening requirements
  # These enforce Constitution Principle III (Security by Default)
  assertions = [
    {
      assertion = !config.services.openssh.settings.PasswordAuthentication;
      message = ''
        SECURITY VIOLATION: SSH password authentication must be disabled.
        Constitution Principle III requires security by default.
        Set services.openssh.settings.PasswordAuthentication = false.
      '';
    }
    {
      assertion = config.services.openssh.settings.PermitRootLogin == "no";
      message = ''
        SECURITY VIOLATION: SSH root login must be denied.
        Constitution Principle III requires security by default.
        Set services.openssh.settings.PermitRootLogin = "no".
      '';
    }
  ];

  # Enable OpenSSH server
  services.openssh = {
    enable = true;

    # SSH daemon settings for maximum security
    settings = {
      # CRITICAL: Disable password authentication
      # All authentication must use SSH keys
      PasswordAuthentication = false;

      # Disable keyboard-interactive authentication
      # Prevents potential PAM-based password prompts
      KbdInteractiveAuthentication = false;

      # CRITICAL: Deny root login via SSH
      # Administrators must login as a normal user and use sudo
      PermitRootLogin = "no";

      # Enable verbose logging for security audit trail
      # Logs are written to systemd journal
      LogLevel = "VERBOSE";

      # Use only modern, secure key exchange algorithms
      # NixOS defaults are already Mozilla-recommended; no changes needed
    };

    # Open SSH port in firewall? No - we rely on Tailscale trust
    # SSH is only accessible via tailscale0 interface
    openFirewall = false;
  };
}
