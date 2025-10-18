#!/usr/bin/env bats

load ./common.bash

@test "publish-draft.sh fast-forwards main to draft" {
  # 1️⃣ Setup fresh local clone + upstream
  readarray -t REPOS <<< "$(setup_test_repos)"
  CLONE="${REPOS[0]}"
  UPSTREAM="${REPOS[1]}"

  cd "$CLONE"

  # 2️⃣ Copy the scripts into the sandbox
  cp ../../../../scripts/*.sh .

  # 3️⃣ Ensure old branches/tags are gone (optional safety)
  git branch -D prepare/v0.1.0 2>/dev/null || true
  git branch -D draft/v0.1.0 2>/dev/null || true
  git tag -d v0.1.0 2>/dev/null || true

  # 4️⃣ create draft branch with new commit
  git checkout -b draft/v0.1.0
  echo "rel" >> file.txt
  git commit -q -am "release draft"
  git push origin draft/v0.1.0  # ensure remote exists
  git push origin main          # sync main, so script can ff from origin

  # 5️⃣ Run the script under test
  run bash publish-draft.sh draft/v0.1.0 v0.1.0 main
  [ "$status" -eq 0 ]

  # 6️⃣ Assertions
  assert_branch_tip main draft/v0.1.0
}
