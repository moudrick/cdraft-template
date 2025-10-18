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
