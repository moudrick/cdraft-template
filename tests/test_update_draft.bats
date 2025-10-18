#!/usr/bin/env bats

load ./common.bash

@test "update-draft.sh creates draft branch and tag from prepare" {
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

  # 4️⃣ Create prepare branch and commit
  git checkout -b prepare/v0.1.0
  echo "new" >> file.txt
  git commit -q -am "prepare v0.1.0"

  # 5️⃣ Run the script under test
  run bash update-draft.sh prepare/v0.1.0 draft/v0.1.0 v0.1.0
  [ "$status" -eq 0 ]

  # 6️⃣ Assertions: branch and tag exist and point correctly
  git show-ref --verify refs/heads/draft/v0.1.0
  git show-ref --verify refs/tags/v0.1.0

  assert_branch_tip draft/v0.1.0 prepare/v0.1.0
}
