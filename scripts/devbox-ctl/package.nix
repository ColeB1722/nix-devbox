# Nix package definition for devbox-ctl
#
# This packages the devbox-ctl Python CLI tool for installation via NixOS modules.
#
# Usage in a NixOS module:
#   environment.systemPackages = [ (pkgs.callPackage ../scripts/devbox-ctl/package.nix {}) ];
#
# Or via flake packages:
#   packages.devbox-ctl = pkgs.callPackage ./scripts/devbox-ctl/package.nix {};

{
  lib,
  python3Packages,
  makeWrapper,
  podman,
  _1password,
  tailscale,
  jq,
}:

python3Packages.buildPythonApplication rec {
  pname = "devbox-ctl";
  version = "1.0.0";
  format = "other";

  src = ./.;

  # Runtime dependencies
  propagatedBuildInputs = with python3Packages; [
    click
  ];

  # Wrap with runtime tools in PATH
  nativeBuildInputs = [ makeWrapper ];

  # No build step - just install the script
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    # Install the Python script
    mkdir -p $out/bin $out/lib
    cp devbox_ctl.py $out/lib/

    # Create wrapper script that sets up the environment
    makeWrapper ${python3Packages.python.interpreter} $out/bin/devbox-ctl \
      --add-flags "$out/lib/devbox_ctl.py" \
      --prefix PATH : ${
        lib.makeBinPath [
          podman
          _1password
          tailscale
          jq
        ]
      } \
      --set PYTHONPATH "${python3Packages.makePythonPath propagatedBuildInputs}"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Container management CLI for the nix-devbox orchestrator";
    homepage = "https://github.com/coal-bap/nix-devbox";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "devbox-ctl";
    platforms = platforms.linux;
  };
}
