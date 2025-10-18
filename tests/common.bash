# common.bash — shared helpers for bats tests
setup_test_repos() {
  SANDBOX_ROOT="tests/sandbox/$(date +%s%N)"
  mkdir -p "$SANDBOX_ROOT"

  # 1️⃣ Create upstream bare repo
  UPSTREAM="$SANDBOX_ROOT/upstream.git"
  git init --bare "$UPSTREAM" &>/dev/null

  # 2️⃣ Clone into local test repo
  CLONE="$SANDBOX_ROOT/clone"
  git clone "$UPSTREAM" "$CLONE" 1>&2
  cd "$CLONE"

  # 3️⃣ Set user for commits
  git config user.email "test@example.com"
  git config user.name "Test User"
  # 4️⃣ Make initial commit
  echo "base" > file.txt
  git add file.txt
  git commit -q -m "initial commit"
  git branch -M main 
  git push -u origin main &>/dev/null

  # ✅ Return paths only on stdout
  echo "$CLONE"
  echo "$UPSTREAM"
}

assert_branch_tip() {
  local branch=$1 ref=$2
  [[ "$(git rev-parse "$branch")" == "$(git rev-parse "$ref")" ]]
}
