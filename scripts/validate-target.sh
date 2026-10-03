#!/usr/bin/env bash
# Validate the `target` input before handing it to syft. Syft accepts both
# filesystem paths/archives and container image references (optionally with
# an explicit source scheme like docker:, registry:, oci-archive:). Only
# filesystem-shaped targets can be checked for existence here; image
# references are left for syft itself to resolve.
set -euo pipefail

TARGET="${1:-.}"

case "$TARGET" in
*://* | docker:* | docker-archive:* | docker-daemon:* | oci:* | oci-archive:* | oci-dir:* | registry:* | podman:* | dir:* | file:*)
	# Explicit non-filesystem source scheme; not our job to validate.
	exit 0
	;;
esac

case "$TARGET" in
*:*)
	# Contains a colon anywhere: either a bare "name:tag"/"name@digest"-style
	# image reference (e.g. "alpine:latest") or a tagged, registry-qualified
	# one (e.g. "ghcr.io/org/app:v1.0.0"). Either way, not a filesystem path.
	exit 0
	;;
esac

case "$TARGET" in
. | ./* | ../* | /*)
	# Unambiguous filesystem path.
	;;
*/*)
	# Ambiguous multi-segment path with no colon: could be "dir/subdir" or an
	# untagged, registry-qualified image reference (e.g. "ghcr.io/org/app").
	# Follow Docker's own heuristic for telling these apart: if the first
	# path segment looks like a registry host (contains a "." or equals
	# "localhost"), treat the whole thing as an image reference.
	first_segment="${TARGET%%/*}"
	case "$first_segment" in
	*.* | localhost) exit 0 ;;
	esac
	;;
esac

if [ ! -e "$TARGET" ]; then
	echo "Error: target path does not exist: $TARGET" >&2
	exit 1
fi
