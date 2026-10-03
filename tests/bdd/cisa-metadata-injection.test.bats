#!/usr/bin/env bats
# Acceptance test for features/cisa-metadata-injection.feature,
# Scenario: Explicit Metadata Input.

setup() {
  FIXTURE_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../fixtures" && pwd)"
  SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../scripts" && pwd)/enrich-cisa.sh"
  OUTPUT_FILE="$(mktemp)"
}

teardown() {
  rm -f "$OUTPUT_FILE"
}

@test "Scenario: Explicit Metadata Input" {
  # Given a raw Syft CycloneDX SBOM
  input="${FIXTURE_DIR}/sample-syft-output.json"

  # When the enrichment runs with the given inputs
  run "$SCRIPT" \
    --input "$input" \
    --output "$OUTPUT_FILE" \
    --name "core-payment-service" \
    --version "2.4.0" \
    --author "DevSecOps Team" \
    --supplier "Acme Corp" \
    --context "post-build"
  [ "$status" -eq 0 ]

  # Then an enriched SBOM file is produced
  [ -s "$OUTPUT_FILE" ]

  # And the JSON property ".metadata.component.name" equals "core-payment-service"
  [ "$(jq -r '.metadata.component.name' "$OUTPUT_FILE")" = "core-payment-service" ]

  # And the JSON property ".metadata.component.version" equals "2.4.0"
  [ "$(jq -r '.metadata.component.version' "$OUTPUT_FILE")" = "2.4.0" ]

  # And the JSON array ".metadata.authors" contains an entry with name "DevSecOps Team"
  [ "$(jq -r '.metadata.authors[] | select(.name=="DevSecOps Team") | .name' "$OUTPUT_FILE")" = "DevSecOps Team" ]

  # And the JSON property ".metadata.supplier.name" equals "Acme Corp"
  [ "$(jq -r '.metadata.supplier.name' "$OUTPUT_FILE")" = "Acme Corp" ]

  # And the JSON array ".metadata.properties" contains a property "cisa:generationContext" with value "post-build"
  [ "$(jq -r '.metadata.properties[] | select(.name=="cisa:generationContext") | .value' "$OUTPUT_FILE")" = "post-build" ]
}
