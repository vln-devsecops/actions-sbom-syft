#!/usr/bin/env bash
# Runs CycloneDX/Sunshine against an enriched SBOM to produce a
# human-readable HTML report.
set -euo pipefail

BIN_DIR="${1:?Usage: $0 <bin-dir> <sbom-path> <output-path>}"
SBOM_PATH="${2:?Usage: $0 <bin-dir> <sbom-path> <output-path>}"
OUTPUT_PATH="${3:?Usage: $0 <bin-dir> <sbom-path> <output-path>}"

if [ ! -f "$SBOM_PATH" ]; then
	echo "Error: SBOM file '$SBOM_PATH' not found." >&2
	exit 1
fi

python3 "$BIN_DIR/sunshine.py" -i "$SBOM_PATH" -o "$OUTPUT_PATH"
