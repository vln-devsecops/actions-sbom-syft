#!/usr/bin/env bash
# Resolve the SBOM component version from, in order of precedence:
#   1. an explicit version argument
#   2. a release-please manifest entry for the target path (falling back to
#      the manifest's root "." entry if the target path has no entry)
#   3. `git describe --tags` at HEAD
#   4. a static draft placeholder
set -euo pipefail

EXPLICIT_VERSION="${1:-}"
MANIFEST_FILE="${2:-.release-please-manifest.json}"
TARGET_DIR="${3:-.}"

if [ -n "$EXPLICIT_VERSION" ]; then
	echo "$EXPLICIT_VERSION"
	exit 0
fi

if [ -f "$MANIFEST_FILE" ]; then
	resolved_version=""
	if jq empty "$MANIFEST_FILE" >/dev/null 2>&1; then
		resolved_version=$(jq -r --arg path "$TARGET_DIR" '.[$path] // .["."] // empty' "$MANIFEST_FILE")
	else
		echo "Warning: ${MANIFEST_FILE} is not valid JSON; ignoring it." >&2
	fi
	if [ -n "$resolved_version" ]; then
		echo "$resolved_version"
		exit 0
	fi
fi

git_version=$(git describe --tags --always 2>/dev/null || true)
if [ -n "$git_version" ]; then
	echo "${git_version#v}"
	exit 0
fi

echo "0.0.0-draft"
