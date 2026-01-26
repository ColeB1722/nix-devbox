# Container Configuration Schema and Validation
#
# This module provides schema definitions and validation functions for
# the container orchestrator configuration in users.nix.
#
# The containers config block controls:
#   - 1Password vault naming conventions
#   - Resource limits (per-user and global)
#   - Lifecycle automation (idle stop, auto-destroy)
#
# Usage:
#   let
#     containers = import ./containers.nix { inherit lib; };
#   in
#     assert containers.validateConfig users.containers;
#     { /* module configuration */ }
#
# Constitution alignment:
#   - Principle III: Security by Default (validates resource limits)
#   - Principle V: Documentation as Code (clear error messages)

{ lib }:

rec {
  # ─────────────────────────────────────────────────────────────────────────────
  # Default Configuration
  # ─────────────────────────────────────────────────────────────────────────────
  # These defaults are used when consumers don't specify values

  defaults = {
    opVault = "DevBox";
    maxPerUser = 5;
    maxGlobal = 7;
    defaultCpu = 2;
    defaultMemory = "4G";
    idleStopDays = 7;
    stoppedDestroyDays = 14;
  };

  # ─────────────────────────────────────────────────────────────────────────────
  # Naming Conventions
  # ─────────────────────────────────────────────────────────────────────────────
  # These functions generate consistent names for 1Password items and Tailscale tags

  # Generate 1Password item name for a user's Tailscale auth key
  # Convention: {username}-tailscale-authkey
  mkAuthKeyItemName = username: "${username}-tailscale-authkey";

  # Generate 1Password reference for retrieving auth key
  # Format: op://{vault}/{username}-tailscale-authkey/password
  mkAuthKeyReference = vault: username: "op://${vault}/${mkAuthKeyItemName username}/password";

  # Generate Tailscale tags for a container as comma-separated string
  # All containers get tag:devcontainer for common ACL rules
  # Each user's containers also get tag:{username}-container for isolation
  # Returns comma-separated string to match Python implementation (get_tailscale_tags)
  mkTailscaleTags = username: "tag:devcontainer,tag:${username}-container";

  # ─────────────────────────────────────────────────────────────────────────────
  # Container Name Validation
  # ─────────────────────────────────────────────────────────────────────────────
  # Container names must follow DNS hostname rules for Tailscale compatibility

  # Validate container name format
  # Rules: alphanumeric + hyphens, 3-63 chars, starts with letter, no consecutive hyphens
  isValidContainerName =
    name:
    let
      len = builtins.stringLength name;
    in
    # Early return for empty or too-short strings to avoid head/last on empty list
    if len < 3 || len > 63 then
      false
    else
      let
        # Check if string matches pattern: starts with letter, contains only a-z, 0-9, hyphen
        chars = lib.stringToCharacters name;
        isAlphaLower = c: (c >= "a" && c <= "z");
        isDigit = c: (c >= "0" && c <= "9");
        isHyphen = c: c == "-";
        isValidChar = c: isAlphaLower c || isDigit c || isHyphen c;
        # Safe to call head/last now since we verified len >= 3
        startsWithLetter = isAlphaLower (builtins.head chars);
        endsWithAlphaNum =
          let
            last = lib.last chars;
          in
          isAlphaLower last || isDigit last;
        allValidChars = builtins.all isValidChar chars;
        # No consecutive hyphens
        noDoubleHyphen = !(lib.hasInfix "--" name);
      in
      startsWithLetter && endsWithAlphaNum && allValidChars && noDoubleHyphen;

  # Validate container name with descriptive error
  validateContainerName =
    name:
    lib.assertMsg (isValidContainerName name) "Container name '${name}' is invalid. Names must be 3-63 characters, start with a letter, end with alphanumeric, contain only lowercase letters, digits, and hyphens (no consecutive hyphens).";

  # ─────────────────────────────────────────────────────────────────────────────
  # Memory String Validation
  # ─────────────────────────────────────────────────────────────────────────────

  # Validate memory string format (e.g., "4G", "512M", "2G")
  # Requires at least 1 (rejects "0G", "0M")
  isValidMemoryString = mem: builtins.isString mem && builtins.match "^[1-9][0-9]*[MG]$" mem != null;

  # ─────────────────────────────────────────────────────────────────────────────
  # Configuration Validators
  # ─────────────────────────────────────────────────────────────────────────────

  # Validate opVault field
  validateOpVault =
    config:
    lib.assertMsg (
      config ? opVault -> builtins.isString config.opVault && config.opVault != ""
    ) "containers.opVault must be a non-empty string";

  # Validate maxPerUser field
  validateMaxPerUser =
    config:
    lib.assertMsg
      (
        config ? maxPerUser
        -> builtins.isInt config.maxPerUser && config.maxPerUser >= 1 && config.maxPerUser <= 100
      )
      "containers.maxPerUser must be an integer between 1 and 100 (got: ${
        if config ? maxPerUser then toString config.maxPerUser else "not set"
      })";

  # Validate maxGlobal field
  validateMaxGlobal =
    config:
    lib.assertMsg
      (
        config ? maxGlobal
        -> builtins.isInt config.maxGlobal && config.maxGlobal >= 1 && config.maxGlobal <= 100
      )
      "containers.maxGlobal must be an integer between 1 and 100 (got: ${
        if config ? maxGlobal then toString config.maxGlobal else "not set"
      })";

  # Validate defaultCpu field
  validateDefaultCpu =
    config:
    lib.assertMsg
      (
        config ? defaultCpu
        -> builtins.isInt config.defaultCpu && config.defaultCpu >= 1 && config.defaultCpu <= 64
      )
      "containers.defaultCpu must be an integer between 1 and 64 (got: ${
        if config ? defaultCpu then toString config.defaultCpu else "not set"
      })";

  # Validate defaultMemory field
  validateDefaultMemory =
    config:
    lib.assertMsg (config ? defaultMemory -> isValidMemoryString config.defaultMemory)
      "containers.defaultMemory must be a valid memory string like '4G' or '512M' (got: ${
        if config ? defaultMemory then toString config.defaultMemory else "not set"
      })";

  # Validate idleStopDays field
  validateIdleStopDays =
    config:
    lib.assertMsg
      (
        config ? idleStopDays
        -> builtins.isInt config.idleStopDays && config.idleStopDays >= 1 && config.idleStopDays <= 365
      )
      "containers.idleStopDays must be an integer between 1 and 365 (got: ${
        if config ? idleStopDays then toString config.idleStopDays else "not set"
      })";

  # Validate stoppedDestroyDays field
  validateStoppedDestroyDays =
    config:
    lib.assertMsg
      (
        config ? stoppedDestroyDays
        ->
          builtins.isInt config.stoppedDestroyDays
          && config.stoppedDestroyDays >= 1
          && config.stoppedDestroyDays <= 365
      )
      "containers.stoppedDestroyDays must be an integer between 1 and 365 (got: ${
        if config ? stoppedDestroyDays then toString config.stoppedDestroyDays else "not set"
      })";

  # Validate logical consistency: stoppedDestroyDays should be >= idleStopDays
  validateLifecycleConsistency =
    config:
    let
      idleStop = config.idleStopDays or defaults.idleStopDays;
      stoppedDestroy = config.stoppedDestroyDays or defaults.stoppedDestroyDays;
    in
    lib.assertMsg (stoppedDestroy >= idleStop)
      "containers.stoppedDestroyDays (${toString stoppedDestroy}) must be >= idleStopDays (${toString idleStop})";

  # Validate logical consistency: maxGlobal should be >= maxPerUser
  validateLimitsConsistency =
    config:
    let
      maxPerUser = config.maxPerUser or defaults.maxPerUser;
      maxGlobal = config.maxGlobal or defaults.maxGlobal;
    in
    lib.assertMsg (
      maxGlobal >= maxPerUser
    ) "containers.maxGlobal (${toString maxGlobal}) must be >= maxPerUser (${toString maxPerUser})";

  # ─────────────────────────────────────────────────────────────────────────────
  # Main Validator
  # ─────────────────────────────────────────────────────────────────────────────

  # Validate entire containers config block
  # Returns true if valid, throws assertion error with message if invalid
  #
  # Usage:
  #   assert containers.validateConfig users.containers;
  #   { /* your config */ }
  #
  validateConfig =
    config:
    validateOpVault config
    && validateMaxPerUser config
    && validateMaxGlobal config
    && validateDefaultCpu config
    && validateDefaultMemory config
    && validateIdleStopDays config
    && validateStoppedDestroyDays config
    && validateLifecycleConsistency config
    && validateLimitsConsistency config;

  # ─────────────────────────────────────────────────────────────────────────────
  # Helper Functions
  # ─────────────────────────────────────────────────────────────────────────────

  # Merge user config with defaults
  # Use this to get a complete config with all fields populated
  withDefaults = config: defaults // config;

  # Get effective config value with default fallback
  getConfig = config: field: config.${field} or defaults.${field};

  # ─────────────────────────────────────────────────────────────────────────────
  # Schema Version
  # ─────────────────────────────────────────────────────────────────────────────

  schemaVersion = "1.0.0";
}
