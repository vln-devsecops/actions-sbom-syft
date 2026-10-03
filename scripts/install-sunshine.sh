#!/usr/bin/env bash
# Fetches CycloneDX/Sunshine's single-file CLI, pinned to a commit SHA
# (it has no tagged releases), into $1. Installs its one runtime
# dependency pinned to a version we control explicitly, rather than
# trusting whatever version constraint (or lack of one) the fetched
# repo's own requirements.txt happens to declare at install time — the
# commit pin only makes sunshine.py itself reproducible, not a live
# `pip install` of an unpinned dependency name.
set -euo pipefail

BIN_DIR="${1:?Usage: $0 <bin-dir> <commit-sha>}"
COMMIT_SHA="${2:?Usage: $0 <bin-dir> <commit-sha>}"
REQUESTS_VERSION="2.34.2"

mkdir -p "$BIN_DIR"
curl -sSfL "https://raw.githubusercontent.com/CycloneDX/sunshine/${COMMIT_SHA}/sunshine.py" \
	-o "$BIN_DIR/sunshine.py"

# --user: the only thing we need is for sunshine.py's `import requests` to
# resolve afterward. Python's per-user site-packages directory is on
# sys.path by default on a standard (non-venv, non -S) interpreter, which
# is what GitHub-hosted runners provide, so no further PATH/PYTHONPATH
# changes are needed for this to be importable in the next step.
python3 -m pip install --quiet --user "requests==${REQUESTS_VERSION}"
