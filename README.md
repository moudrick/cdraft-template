[![License](https://img.shields.io/github/license/localcompose/locom)](LICENSE)
[![Test shell scripts](https://github.com/moudrick/cdraft-template/actions/workflows/test-shell.yml/badge.svg)](https://github.com/moudrick/cdraft-template/actions/workflows/test-shell.yml)

# Continuous Drafting — template scaffold

A *spherical repo in vacuum* template implementing your **Continuous Drafting** flow (prepare → draft → publish). This is a single-file scaffold (template layout + example scripts + GitHub Actions) intended to be copied into a real repo and adapted. The goal: **minimal cognitive overhead**, deterministic, and reproducible.

> ⚠️ **Project Status: Experimental**
>
> This repository is under active evaluation and testing.
> The Continuous Drafting (CD) workflow is being validated for practical use.
> Expect breaking changes and evolving design until the first stable tag (v1.0.0).
>
> Use at your own discretion. Feedback and testing contributions are welcome!

---

## Goals implemented

- Prepare draft releases from `prepare/vX.Y.Z` branches.
- Maintain a `draft/vX.Y.Z` branch that is a single squashed commit on top of `main` (or a predecessor release branch).
- Force-overwrite the tag for the draft release on each update so goreleaser (CI) rebuilds and overwrites a *draft* GitHub Release.
- Manual workflow dispatch `Publish draft` to fast-forward `main` to the draft commit and mark the release as published (or change metadata).
- Scripts provided to: squash-to-one-commit with deterministic message, retag, push force, check fast-forwardability, and perform `--ff-only` merge locally.

---

## Suggested repository layout

```
/ (repo root)
├─ README.md                 # this document
├─ scripts/
│  ├─ squash-to-fixed.sh     # transform current branch into single commit on top of base
│  ├─ update-draft.sh        # sync prepare -> draft branch, retag and push
│  ├─ publish-draft.sh       # local helper to ff-only merge draft into main and push
│  └─ ff-sanity.sh           # small utilities for checks
├─ .github/
│  └─ workflows/
│     ├─ draft-release.yml   # CI: published on tag -> run goreleaser and create/update draft release
│     └─ publish-release.yml # Manual dispatch: mark release published and optionally create GitHub "latest"
├─ .goreleaser.yml           # goreleaser configuration for draft releases
└─ Makefile                  # convenience targets
```

---

## Important policies / notes

- **Tags are rewritten** for drafts: you will need to `git push --force` the tag to the remote to update it. This rebases history and *rewrites the tag*, which is fine for draft flow but warn collaborators.
- Keep `prepare/*` -> `draft/*` transitions reproducible. The simplest mechanism is `git reset --soft origin/<base>` then `git commit -m "prepare vX.Y.Z"`.
- The CI (goreleaser) must be configured to create or update a GitHub Release in `draft` mode. Each run should overwrite previous draft release assets.
- Manual `Publish draft` workflow should only move `main` forward with a fast-forward. Use `--ff-only` locally and push.

---

## Scripts (drop into `scripts/`)

### `scripts/squash-to-fixed.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

# Usage: squash-to-fixed.sh <base-ref> <fixed-message>
# Example: squash-to-fixed.sh origin/main "prepare v0.0.3-poc"

base=${1:-origin/main}
message=${2:-"prepare v0.0.0"}

echo "Fetching ${base}..."
git fetch origin

# ensure we are on a branch (not detached)
branch=$(git symbolic-ref --short -q HEAD) || {
  echo "Not on a branch. Checkout the branch you want to squash." >&2
  exit 1
}

# Safety: make sure there are changes compared to base
if git diff --quiet ${base}..HEAD; then
  echo "No differences between ${base} and HEAD; nothing to squash." && exit 0
fi

# soft-reset to base, stage all changes and commit with the fixed message
git reset --soft ${base}

# create single commit
GIT_COMMITTER_DATE="$(git show -s --format=%ci HEAD)" git commit -m "${message}"

echo "Branch ${branch} now contains a single commit on top of ${base} with message:\n  ${message}"

echo "You should now retag if needed and force-push the branch if desired."
```

Notes:
- We preserve the committer date by reusing HEAD's date; remove if not desired.
- This is deterministic and non-interactive.

---

### `scripts/update-draft.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

# Usage: update-draft.sh <prepare-branch> <draft-branch> <tag>
# Example: update-draft.sh prepare/v0.0.3-poc draft/v0.0.3-poc v0.0.3-poc

prepare=${1:-}
draft=${2:-}
tag=${3:-}

if [[ -z "$prepare" || -z "$draft" || -z "$tag" ]]; then
  echo "Usage: $0 <prepare-branch> <draft-branch> <tag>" >&2
  exit 2
fi

# fetch remote state
git fetch origin

# ensure prepare branch exists locally or track remote
git checkout -B "$prepare" "origin/$prepare" || git checkout -B "$prepare" "$prepare"

# Ensure prepare is a single-commit on top of the chosen base (optional manual step)
# At this point we assume you already ran squash-to-fixed.sh on prepare branch.

# Create/update draft branch to point at the same commit
git branch -f "$draft" "$prepare"

# Move tag to that commit (force)
git tag -f "$tag" "$draft"

# Push draft branch and tag (force) to origin
# Use --force-with-lease if you want a bit more safety

echo "Pushing draft branch and tag to origin (force)..."
git push origin "$draft" --force

git push origin refs/tags/$tag --force

echo "Draft updated: branch=$draft tag=$tag -> commit $(git rev-parse $draft)"
```

Notes:
- This script forces the draft branch and tag; you may prefer `--force-with-lease`.
- On CI, tag pushes will trigger the release workflow.

---

### `scripts/publish-draft.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

# Usage: publish-draft.sh <draft-branch> <tag> <main-branch>
# Example: publish-draft.sh draft/v0.0.3-poc v0.0.3-poc main

draft=${1:-}
tag=${2:-}
main=${3:-main}

if [[ -z "$draft" || -z "$tag" ]]; then
  echo "Usage: $0 <draft-branch> <tag> [main-branch]" >&2
  exit 2
fi

git fetch origin

# Make sure draft exists locally
if ! git show-ref --verify --quiet refs/heads/$draft; then
  git checkout -b $draft origin/$draft
else
  git checkout $draft
  git reset --hard origin/$draft
fi

# Check ff-ability
if git merge-base --is-ancestor origin/$main $draft; then
  echo "Fast-forward possible: merging $draft into $main"
  git checkout $main
  git pull --ff-only origin $main
  git merge --ff-only $draft
  git push origin $main
  echo "Main updated to $(git rev-parse HEAD); tag $tag already points at the draft commit."
else
  echo "ERROR: $draft is not a fast-forward on origin/$main. Do not publish." >&2
  exit 1
fi
```

Notes:
- This is a local helper for performing the final fast-forward merge and push.
- You can turn this into a GitHub Action that runs on `workflow_dispatch` with a `repository_dispatch` protected by required reviewers, but that's more complex (we put a simple local helper here).

---

## GitHub Actions

Below are two workflows to put into `.github/workflows/`.

### `.github/workflows/draft-release.yml`

Triggers: `push` to tags matching `v*.*.*` (or your tag regexp). When the tag is pushed/updated, goreleaser runs and creates/overwrites a *draft* GitHub Release.

```yaml
name: Draft release (CI build)

on:
  push:
    tags:
      - 'v*.*.**' # match tags like v1.2.3 and v1.2.3-poc; adapt if needed

permissions:
  contents: write
  packages: write
  actions: write

jobs:
  build-and-draft:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Set up Go
        uses: actions/setup-go@v4
        with:
          go-version: '1.20'

      - name: Install goreleaser
        uses: goreleaser/goreleaser-action@v3
        with:
          version: latest
          args: --rm-dist

      - name: Run goreleaser (draft)
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          goreleaser release --rm-dist --snapshot --skip-publish || true

      - name: Run goreleaser to publish a Draft GitHub Release
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          # Run goreleaser with draft enabled in .goreleaser.yml; this will create a draft release and upload artifacts
          goreleaser release --rm-dist || exit 1
```

Notes:
- The workflow runs goreleaser which will create/update a Release for the pushed tag. The `.goreleaser.yml` should have `release.draft: true` so the GitHub Release is created as draft.
- For force-pushed tags, GitHub will trigger the workflow on each update.

### `.github/workflows/publish-release.yml`

Triggers: manual `workflow_dispatch`. Intention: mark a Release as published (non-draft) and optionally set it as `latest`. This job must be protected by repo permissions.

```yaml
name: Publish draft

on:
  workflow_dispatch:
    inputs:
      tag:
        description: 'Tag to publish'
        required: true

permissions:
  contents: write
  issues: write

jobs:
  publish:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Mark release as published
        uses: actions-ecosystem/action-update-release@v1
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          tag: ${{ github.event.inputs.tag }}
          draft: false
          prerelease: false

      - name: Optional: set release as latest
        run: |
          echo "Release ${{ github.event.inputs.tag }} marked published. Consider marking as latest via GitHub UI if desired."
```

Notes:
- `action-update-release` is a community action that can edit an existing Release. If unavailable, replace with a small `curl` against the GitHub API.
- You may prefer to do the final `ff-only` merge as a step here if you have a protected, automated service account and careful checks. Many teams prefer to do the final FF merge manually from a maintainer's machine to keep reviewers comfortable.

---

## Example `.goreleaser.yml` (minimal, draft + overwrite behavior)

```yaml
project_name: myapp

release:
  draft: true
  # "overwrite" in goreleaser context means that goreleaser will attempt
  # to create the release and update assets. Behavior depends on GitHub api.

builds:
  - id: myapp
    main: ./cmd/myapp
    binary: myapp

archives:
  - format: tar.gz

changelog:
  skip: true

github:
  owner: your-org-or-user
  name: your-repo

# add other goreleaser sections (signing, brew, snap, etc.) as needed
```

Notes:
- Goreleaser will create a draft GitHub Release when running `goreleaser release` with `GITHUB_TOKEN` available. The release is associated with the pushed tag.
- Ensure `GITHUB_TOKEN` has repository permissions to create releases (the default `GITHUB_TOKEN` usually does).

---

## Makefile (convenience targets)

```makefile
.PHONY: squash tag draft publish

# Usage: make squash BRANCH=prepare/v0.0.3-poc BASE=origin/main MSG='prepare v0.0.3-poc'
squash:
	./scripts/squash-to-fixed.sh ${BASE} "${MSG}"

# Usage: make draft PREPARE=prepare/v0.0.3-poc DRAFT=draft/v0.0.3-poc TAG=v0.0.3-poc
draft:
	./scripts/update-draft.sh ${PREPARE} ${DRAFT} ${TAG}

# Usage: make publish DRAFT=draft/v0.0.3-poc TAG=v0.0.3-poc
publish:
	./scripts/publish-draft.sh ${DRAFT} ${TAG}
```

---

## Example workflow (high-level)

1. Developer opens PR to `prepare/vX.Y.Z` with feature(s).
2. On merge to `prepare/vX.Y.Z`, a maintainer runs locally or in CI `scripts/squash-to-fixed.sh origin/main "prepare vX.Y.Z"` or ensures the branch is already squashed.
3. Run `scripts/update-draft.sh prepare/vX.Y.Z draft/vX.Y.Z vX.Y.Z` which:
   - creates/updates `draft/vX.Y.Z` branch pointing at the squashed commit
   - force-updates the tag `vX.Y.Z` to that commit and pushes it to origin
4. CI (`.github/workflows/draft-release.yml`) triggers on the tag and runs goreleaser, creating/updating a *draft* GitHub Release and uploading artifacts.
5. After testing/dry-run, a maintainer triggers `Publish draft` workflow dispatch that marks the release as published (or runs the `scripts/publish-draft.sh` locally to fast-forward main).

---

## Caveats and recommended protections

- Force-pushing tags and branches can be disruptive. Use `--force-with-lease` where possible.
- Protect `main` with required status checks and branch protections so `--ff-only` merges cannot accidentally be bypassed.
- Consider requiring a maintainer review before `Publish draft` workflow dispatch.
- If you plan to support multiple parallel release preparation lines (example: `prepare/v1.2.0` and `prepare/v1.1.5`), make sure to parameterize the `update-draft.sh` base selection logic to rebase onto predecessor releases when appropriate.

---

## Next steps if you want this turned into a real template repo

I can also:

- Create a full tree of files (actual repo) with executable scripts and GitHub Action YAMLs and provide it as a downloadable zip.
- Make the `publish` workflow perform `git` operations server-side using a service account (requires extra repo secrets and careful protection).
- Add tests and a small local dry-run mode to simulate tag and branch updates without pushing.

Tell me which of these you'd like and I'll produce the concrete repo files ready to copy into a new repository.
