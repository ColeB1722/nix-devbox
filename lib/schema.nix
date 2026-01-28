# User Data Schema Validation
#
# This module provides validation functions for consumer-provided user data.
# It ensures that user configurations meet the required schema before
# attempting to build the NixOS configuration.
#
# Usage:
#   let
#     schema = import ./schema.nix { inherit lib; };
#   in
#     assert schema.validateUsers users;
#     { /* module configuration */ }

{ lib }:

rec {
  # ─────────────────────────────────────────────────────────────────────────────
  # Individual Field Validators
  # ─────────────────────────────────────────────────────────────────────────────

  # Validate that a required field exists
  hasField =
    name: field: user:
    lib.assertMsg (user ? ${field}) "User '${name}' is missing required field '${field}'";

  # Validate that a string field is non-empty
  # Self-contained: checks existence before accessing the field
  nonEmptyString =
    name: field: user:
    lib.assertMsg (user ? ${field} && builtins.isString user.${field} && user.${field} != "")
      "User '${name}' field '${field}' must be a non-empty string (got: ${
        if user ? ${field} then builtins.typeOf user.${field} else "missing"
      })";

  # Validate UID is in valid range (1000-65533, not system range)
  validUid =
    name: user:
    lib.assertMsg (builtins.isInt user.uid) "User '${name}' uid must be an integer (got: ${builtins.typeOf user.uid})"
    && lib.assertMsg (user.uid != 0) "User '${name}' uid cannot be 0 (root is forbidden)"
    &&
      lib.assertMsg (user.uid >= 1000)
        "User '${name}' uid must be >= 1000 (got ${toString user.uid}); UIDs 1-999 are reserved for system accounts"
    && lib.assertMsg (
      user.uid <= 65533
    ) "User '${name}' uid must be <= 65533 (got ${toString user.uid})";

  # Validate SSH key format (must start with ssh-)
  validSshKey =
    name: key:
    lib.assertMsg (builtins.isString key && lib.hasPrefix "ssh-" key)
      "User '${name}' has invalid SSH key format: keys must start with 'ssh-' (e.g., 'ssh-ed25519', 'ssh-rsa')";

  # Validate SSH keys list is non-empty and all keys are valid
  validSshKeys =
    name: user:
    lib.assertMsg (builtins.isList user.sshKeys) "User '${name}' sshKeys must be a list (got: ${builtins.typeOf user.sshKeys})"
    && lib.assertMsg (
      builtins.length user.sshKeys > 0
    ) "User '${name}' must have at least one SSH public key for remote access"
    && builtins.all (validSshKey name) user.sshKeys;

  # Validate isAdmin is a boolean
  validIsAdmin =
    name: user:
    lib.assertMsg (builtins.isBool user.isAdmin) "User '${name}' isAdmin must be a boolean (got: ${builtins.typeOf user.isAdmin})";

  # Validate extraGroups is a list of strings (optional field)
  validExtraGroups =
    name: user:
    if user ? extraGroups then
      lib.assertMsg (builtins.isList user.extraGroups) "User '${name}' extraGroups must be a list (got: ${builtins.typeOf user.extraGroups})"
      && lib.assertMsg (builtins.all builtins.isString user.extraGroups) "User '${name}' extraGroups must contain only strings"
    else
      true;

  # ─────────────────────────────────────────────────────────────────────────────
  # User Record Validator
  # ─────────────────────────────────────────────────────────────────────────────

  # Validate a single user record
  # Returns true if valid, throws assertion error with message if invalid
  validateUser =
    name: user:
    # Required fields existence
    hasField name "name" user
    && hasField name "uid" user
    && hasField name "description" user
    && hasField name "email" user
    && hasField name "gitUser" user
    && hasField name "isAdmin" user
    && hasField name "sshKeys" user
    &&

      # Field value validation
      lib.assertMsg (user.name == name)
        "User '${name}' has mismatched name field: attribute key is '${name}' but name field is '${user.name}'"
    && nonEmptyString name "description" user
    && nonEmptyString name "email" user
    && nonEmptyString name "gitUser" user
    && validUid name user
    && validIsAdmin name user
    && validSshKeys name user
    && validExtraGroups name user;

  # ─────────────────────────────────────────────────────────────────────────────
  # Collection Validators
  # ─────────────────────────────────────────────────────────────────────────────

  # Get user record names (exclude collection fields)
  collectionFields = [
    "allUserNames"
    "adminUserNames"
    "codeServerPorts"
  ];

  getUserNames =
    users: builtins.filter (n: !(builtins.elem n collectionFields)) (builtins.attrNames users);

  # Validate allUserNames collection field
  validateAllUserNames =
    users:
    let
      actualUserNames = getUserNames users;
    in
    lib.assertMsg (users ? allUserNames) "users.nix must define 'allUserNames' list"
    && lib.assertMsg (builtins.isList users.allUserNames) "'allUserNames' must be a list (got: ${builtins.typeOf users.allUserNames})"
    && lib.assertMsg (
      builtins.length users.allUserNames > 0
    ) "'allUserNames' must contain at least one user"
    &&
      lib.assertMsg (builtins.all (n: builtins.elem n actualUserNames) users.allUserNames)
        "'allUserNames' contains users that are not defined: ${
          builtins.concatStringsSep ", " (
            builtins.filter (n: !(builtins.elem n actualUserNames)) users.allUserNames
          )
        }";

  # Validate adminUserNames collection field
  validateAdminUserNames =
    users:
    lib.assertMsg (users ? adminUserNames) "users.nix must define 'adminUserNames' list"
    && lib.assertMsg (builtins.isList users.adminUserNames) "'adminUserNames' must be a list (got: ${builtins.typeOf users.adminUserNames})"
    &&
      lib.assertMsg (builtins.all (n: builtins.elem n users.allUserNames) users.adminUserNames)
        "'adminUserNames' contains users not in 'allUserNames': ${
          builtins.concatStringsSep ", " (
            builtins.filter (n: !(builtins.elem n users.allUserNames)) users.adminUserNames
          )
        }"
    &&
      # Verify isAdmin consistency
      lib.assertMsg (builtins.all (
        n: users.${n}.isAdmin
      ) users.adminUserNames) "'adminUserNames' contains users with isAdmin = false";

  # Validate codeServerPorts (optional but recommended)
  validateCodeServerPorts =
    users:
    if users ? codeServerPorts then
      lib.assertMsg (builtins.isAttrs users.codeServerPorts) "'codeServerPorts' must be an attribute set (got: ${builtins.typeOf users.codeServerPorts})"
      && lib.assertMsg (builtins.all (n: builtins.elem n users.allUserNames) (
        builtins.attrNames users.codeServerPorts
      )) "'codeServerPorts' contains users not in 'allUserNames'"
      && lib.assertMsg (builtins.all (p: builtins.isInt p && p >= 1024 && p <= 65535) (
        builtins.attrValues users.codeServerPorts
      )) "'codeServerPorts' values must be integers between 1024 and 65535"
    else
      true;

  # ─────────────────────────────────────────────────────────────────────────────
  # Main Validator
  # ─────────────────────────────────────────────────────────────────────────────

  # Validate entire users attrset
  # This is the main entry point for validation
  #
  # Usage:
  #   assert schema.validateUsers users;
  #   { /* your config */ }
  #
  validateUsers =
    users:
    let
      userNames = getUserNames users;
    in
    # Validate collection fields
    validateAllUserNames users
    && validateAdminUserNames users
    && validateCodeServerPorts users
    &&
      # Validate each user record
      builtins.all (name: validateUser name users.${name}) userNames;

  # ─────────────────────────────────────────────────────────────────────────────
  # Schema Version
  # ─────────────────────────────────────────────────────────────────────────────
  # Increment this when making breaking changes to the schema
  # Consumers can check this to get migration hints

  schemaVersion = "1.1.0";

  # Migration hints for future schema changes
  migrationHints = {
    "1.1.0" = "Removed 'containers' config block (orchestrator feature removed).";
  };
}
