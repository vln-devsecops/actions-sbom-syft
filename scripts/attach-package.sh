#!/usr/bin/env bash
# Embed a generated SBOM into a built language-ecosystem archive:
#   npm   -> package/sbom.json inside the tarball
#   maven -> META-INF/sbom/application-sbom.json inside the jar/war/ear
#   nuget -> sbom.json at the package root inside the nupkg
set -euo pipefail

PACKAGE_TYPE="${1:-none}"
FILE_PATH="${2:-}"
SBOM_PATH="${3:-sbom.json}"

if [ "$PACKAGE_TYPE" = "none" ]; then
	exit 0
fi

if [ -z "$FILE_PATH" ]; then
	echo "Error: package-file-path is required when package-type is not 'none'." >&2
	exit 1
fi

if [ ! -f "$FILE_PATH" ]; then
	echo "Error: target package file '$FILE_PATH' not found." >&2
	exit 1
fi

if [ ! -f "$SBOM_PATH" ]; then
	echo "Error: SBOM file '$SBOM_PATH' not found." >&2
	exit 1
fi

FILE_PATH="$(cd "$(dirname "$FILE_PATH")" && pwd)/$(basename "$FILE_PATH")"
SBOM_PATH="$(cd "$(dirname "$SBOM_PATH")" && pwd)/$(basename "$SBOM_PATH")"

case "$PACKAGE_TYPE" in
npm)
	tmp_dir="$(mktemp -d)"
	trap 'rm -rf "$tmp_dir"' EXIT
	tar -xzf "$FILE_PATH" -C "$tmp_dir"
	cp "$SBOM_PATH" "$tmp_dir/package/sbom.json"
	tar -czf "$FILE_PATH" -C "$tmp_dir" package
	;;
maven)
	tmp_dir="$(mktemp -d)"
	trap 'rm -rf "$tmp_dir"' EXIT
	mkdir -p "$tmp_dir/META-INF/sbom"
	cp "$SBOM_PATH" "$tmp_dir/META-INF/sbom/application-sbom.json"
	(cd "$tmp_dir" && zip -q -g -r "$FILE_PATH" META-INF)
	;;
nuget)
	(cd "$(dirname "$SBOM_PATH")" && zip -q -g -j "$FILE_PATH" "$(basename "$SBOM_PATH")")
	;;
*)
	echo "Error: Unsupported package-type: $PACKAGE_TYPE" >&2
	exit 1
	;;
esac
