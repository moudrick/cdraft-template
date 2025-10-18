# tests

Template validation files

```
.(repo root)
/tests/
├─ common.bash              # shared setup for tests (temporary repos, helpers)
├─ test_squash.bats         # unit test for squash-to-fixed.sh
├─ test_update_draft.bats   # test for update-draft.sh
├─ test_publish_draft.bats  # test for publish-draft.sh
└─ bats-local.env           # optional env overrides for CI
.github/workflows/test-shell.yml  # new workflow running Bats tests
```
