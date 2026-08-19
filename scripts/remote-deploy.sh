#!/usr/bin/env bash
# Pull latest publishable files on the server.
# First-time setup: clone this repo to DEPLOY_PATH (see README).
set -euxo pipefail

DEPLOY_PATH="${DEPLOY_PATH:-/opt/yearplan.sermestre.es}"
DEPLOY_BRANCH="${DEPLOY_BRANCH:-master}"

# Git 2.35+ rechaza repos cuyo dueño en disco ≠ usuario SSH (p. ej. clone como root, deploy como otro user).
git_deploy() {
  git -c "safe.directory=${DEPLOY_PATH}" "$@"
}

if [ ! -d "${DEPLOY_PATH}/.git" ]; then
  echo "ERROR: ${DEPLOY_PATH} is not a git checkout. Clone the repo there first." >&2
  exit 1
fi

cd "${DEPLOY_PATH}"
git_deploy fetch origin
git_deploy checkout -B "${DEPLOY_BRANCH}" "origin/${DEPLOY_BRANCH}"
git_deploy reset --hard "origin/${DEPLOY_BRANCH}"
git_deploy clean -fd

test -f index.html
test -f programacion_index.html

date -u "+[deploy] %Y-%m-%dT%H:%M:%SZ yearplan ready at ${DEPLOY_PATH} (${DEPLOY_BRANCH})"
