# Future Enhancements

This document tracks potential improvements that have been evaluated but deferred.

## Automated Flake Input Updates (`update-flake-lock`)

**Status:** Evaluated, deferred  
**Priority:** Medium  
**Effort:** Low (single workflow file)

### What It Does

[DeterminateSystems/update-flake-lock](https://github.com/DeterminateSystems/update-flake-lock) automatically creates PRs to update `flake.lock` on a schedule, keeping dependencies like `nixpkgs`, `home-manager`, and `nixos-wsl` current.

### Why It's Valuable

- **Security:** Nixpkgs receives frequent CVE patches; automated updates ensure timely remediation
- **Freshness:** Prevents dependency drift where inputs become months out of date
- **Visibility:** PRs show exactly what changed, with full CI validation

### Why It Was Deferred

- **Review burden:** Nixpkgs updates can be large; ~4 PRs/month require attention
- **Current workflow:** Manual `just update` + `nix flake update` provides explicit control
- **Release cadence:** Automated PRs need careful target branch configuration to fit the `release/*` → `main` flow

### Implementation When Ready

1. Create `.github/workflows/update-flake-lock.yml`:

```yaml
name: Update flake.lock

on:
  workflow_dispatch: # Allow manual triggering
  schedule:
    - cron: "0 9 * * 1" # Weekly on Monday at 9am

jobs:
  update-flake-lock:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write
    steps:
      - uses: actions/checkout@v4

      - uses: DeterminateSystems/determinate-nix-action@v3

      - name: Update flake.lock
        uses: DeterminateSystems/update-flake-lock@main
        with:
          pr-title: "chore(deps): update flake.lock"
          pr-labels: |
            dependencies
            automated
          # Target release branch instead of main
          # branch: release/vX.Y.Z
```

2. Configure target branch to match current release (e.g., `release/v0.0.8`)

3. Consider adding `pr-reviewers` to auto-assign for review

### Complementary Tooling

This pairs well with `flake-checker-action` (already implemented):
- `flake-checker` warns about stale/insecure inputs during CI
- `update-flake-lock` creates the PR to fix it

### Decision Criteria for Implementation

Implement when any of these apply:
- Security policy requires timely nixpkgs updates
- Team forgets to run `just update` regularly
- `flake-checker` warnings become frequent
- Moving to a continuous release model (vs. discrete versions)

---

## Other Potential Enhancements

### `flake-parts` Migration

**Status:** Documented in `darwin/README.md`  
**Trigger:** Evaluate when implementing Darwin support

See [darwin/README.md](../darwin/README.md#consider-flake-parts-at-darwin-implementation-time) for details.