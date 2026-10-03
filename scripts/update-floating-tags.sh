#!/usr/bin/env bash
# Move the floating "vX" and "vX.Y" tags to point at a just-released full
# version tag "vX.Y.Z", so consumers pinning to @v1 or @v1.2 pick up new
# releases automatically. Run from a checkout with `origin` set and
# credentials to push tags.
set -euo pipefail

TAG="${1:?Usage: $0 <full version tag, e.g. v1.2.3>}"

if [[ ! "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
	echo "Error: expected a full version tag like v1.2.3, got '$TAG'." >&2
	exit 1
fi

if ! git rev-parse --verify --quiet "refs/tags/$TAG" >/dev/null; then
	echo "Error: tag '$TAG' does not exist locally." >&2
	exit 1
fi

major="${TAG%%.*}"
rest="${TAG#*.}"
minor_num="${rest%%.*}"
minor="${major}.${minor_num}"

git tag -f "$major" "$TAG" >/dev/null
git tag -f "$minor" "$TAG" >/dev/null

git push --force origin "refs/tags/$major" "refs/tags/$minor"
