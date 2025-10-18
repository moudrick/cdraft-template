#!/usr/bin/env bats

load ./common.bash

@test "squash-to-fixed.sh creates a single commit on top of base" {
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

  # 4️⃣ simulate a branch with multiple commits
  git checkout -b prepare/v0.1.0
  echo "feat1" >> file.txt; git add .; git commit -q -m "feat1"
  echo "feat2" >> file.txt; git add .; git commit -q -m "feat2"

  # 5️⃣ Run the script under test
  run bash squash-to-fixed.sh origin/main "prepare v0.1.0"
  [ "$status" -eq 0 ]

  # 6️⃣ Assertions
  commits=$(git rev-list origin/main..HEAD | wc -l)
  [ "$commits" -eq 1 ]

  lastmsg=$(git log -1 --pretty=%B)
  [[ "$lastmsg" == "prepare v0.1.0" ]]
}
