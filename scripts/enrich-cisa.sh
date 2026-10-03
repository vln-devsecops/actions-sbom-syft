#!/usr/bin/env bash
# Enrich a raw Syft CycloneDX SBOM with the CISA minimum-required metadata
# fields: component name/version, an author, an optional supplier, and a
# cisa:generationContext property.
set -euo pipefail

INPUT_FILE=""
OUTPUT_FILE=""
NAME=""
VERSION=""
AUTHOR=""
SUPPLIER=""
CONTEXT="post-build"

usage() {
	echo "Usage: $0 --input FILE --output FILE --name NAME --version VERSION --author AUTHOR [--supplier SUPPLIER] [--context CONTEXT]" >&2
}

while [[ $# -gt 0 ]]; do
	case "$1" in
	--input | --output | --name | --version | --author | --supplier | --context)
		if [ $# -lt 2 ]; then
			echo "Error: '$1' requires a value." >&2
			usage
			exit 1
		fi
		;;
	esac
	case "$1" in
	--input)
		INPUT_FILE="$2"
		shift 2
		;;
	--output)
		OUTPUT_FILE="$2"
		shift 2
		;;
	--name)
		NAME="$2"
		shift 2
		;;
	--version)
		VERSION="$2"
		shift 2
		;;
	--author)
		AUTHOR="$2"
		shift 2
		;;
	--supplier)
		SUPPLIER="$2"
		shift 2
		;;
	--context)
		CONTEXT="$2"
		shift 2
		;;
	*)
		echo "Error: unknown argument '$1'" >&2
		usage
		exit 1
		;;
	esac
done

if [ -z "$INPUT_FILE" ] || [ -z "$OUTPUT_FILE" ] || [ -z "$NAME" ] || [ -z "$AUTHOR" ]; then
	echo "Error: --input, --output, --name, and --author are required." >&2
	usage
	exit 1
fi

if [ ! -f "$INPUT_FILE" ]; then
	echo "Error: input file '$INPUT_FILE' not found." >&2
	exit 1
fi

if ! jq empty "$INPUT_FILE" >/dev/null 2>&1; then
	echo "Error: input file '$INPUT_FILE' is not valid JSON." >&2
	exit 1
fi

tmp_output="$(mktemp)"
trap 'rm -f "$tmp_output"' EXIT

jq \
	--arg name "$NAME" \
	--arg version "$VERSION" \
	--arg author "$AUTHOR" \
	--arg supplier "$SUPPLIER" \
	--arg context "$CONTEXT" \
	'
  .metadata.component.name = $name |
  .metadata.component.version = $version |
  .metadata.authors = ( (.metadata.authors // []) + [{"name": $author}] | unique_by(.name) ) |
  (if $supplier != "" then .metadata.supplier = {"name": $supplier} else . end) |
  .metadata.properties = ( (.metadata.properties // []) + [{"name": "cisa:generationContext", "value": $context}] | unique_by(.name) )
  ' "$INPUT_FILE" >"$tmp_output"

mv "$tmp_output" "$OUTPUT_FILE"
trap - EXIT
