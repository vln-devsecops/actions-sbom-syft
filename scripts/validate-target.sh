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
. | ./* | ../* | /*)
	# Unambiguous filesystem path.
	;;
*/*)
	# Ambiguous: could be "subdir/path" or "registry.example.com/repo:tag".
	# Treat it as an image reference if the last path segment contains a colon
	# (the image tag/digest separator), otherwise as a filesystem path.
	last_segment="${TARGET##*/}"
	case "$last_segment" in
	*:*) exit 0 ;;
	esac
	;;
esac

if [ ! -e "$TARGET" ]; then
	echo "Error: target path does not exist: $TARGET" >&2
	exit 1
fi
