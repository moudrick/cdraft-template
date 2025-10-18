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
