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