#!/usr/bin/env bash
# Pull latest publishable files on the server.
# First-time setup: clone this repo to DEPLOY_PATH (see README).
set -euxo pipefail

DEPLOY_PATH="${DEPLOY_PATH:-/opt/yearplan.sermestre.es}"
DEPLOY_BRANCH="${DEPLOY_BRANCH:-master}"

if [ ! -d "${DEPLOY_PATH}/.git" ]; then
  echo "ERROR: ${DEPLOY_PATH} is not a git checkout. Clone the repo there first." >&2
  exit 1
fi

cd "${DEPLOY_PATH}"
git fetch origin
git checkout -B "${DEPLOY_BRANCH}" "origin/${DEPLOY_BRANCH}"
git reset --hard "origin/${DEPLOY_BRANCH}"
git clean -fd

test -f index.html
test -f programacion_index.html

date -u "+[deploy] %Y-%m-%dT%H:%M:%SZ yearplan ready at ${DEPLOY_PATH} (${DEPLOY_BRANCH})"
