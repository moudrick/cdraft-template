#!/usr/bin/env bash
set -uo pipefail
trap 'echo "ERROR: failed at line $LINENO (last cmd: $BASH_COMMAND)"; exit 1' ERR

BASE=${1:-origin/main}
MSG=${2:-"prepare v0.0.0"}

echo "INFO: base=$BASE msg=$MSG"

# Ensure we can refer to the base
# If base is a remote ref (origin/...) ensure we have it locally
if [[ "$BASE" == origin/* ]]; then
  echo "INFO: fetching origin..."
  git fetch origin --prune --depth=1 >/dev/null 2>&1 || true
fi

# Check base is resolvable
if ! git rev-parse --verify "$BASE" >/dev/null 2>&1; then
  echo "ERROR: base ref '$BASE' not found locally (try 'git fetch origin')"
  exit 2
fi

# ensure on a branch
BR=$(git symbolic-ref --short -q HEAD || true)
if [[ -z "$BR" ]]; then
  echo "ERROR: not on a branch (detached HEAD). Please checkout your branch first."
  exit 3
fi

# Check there are differences to squash
if git diff --quiet "$BASE"..HEAD; then
  echo "INFO: no differences between $BASE and HEAD; nothing to squash."
  exit 0
fi

# soft-reset to base and commit all staged changes with fixed message
echo "INFO: performing git reset --soft $BASE"
git reset --soft "$BASE"

# sanity: ensure staged changes exist (index not empty)
if git diff --cached --quiet; then
  # nothing staged -> stage all modified/untracked
  git add -A
fi

if git diff --cached --quiet; then
  echo "ERROR: nothing staged after reset; aborting."
  exit 4
fi

# preserve author/committer dates optionally or let git set them
git commit -m "$MSG"

echo "INFO: squash commit created: $(git rev-parse --short HEAD)"
