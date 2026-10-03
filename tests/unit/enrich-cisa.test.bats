#!/usr/bin/env bats

setup() {
  FIXTURE_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../fixtures" && pwd)"
  SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../scripts" && pwd)/enrich-cisa.sh"
  INPUT_FILE="${FIXTURE_DIR}/sample-syft-output.json"
  OUTPUT_FILE="$(mktemp)"
}

teardown() {
  rm -f "$OUTPUT_FILE"
}

@test "enrich-cisa: injects name, version, authors, supplier, and generationContext" {
  run "$SCRIPT" \
    --input "$INPUT_FILE" \
    --output "$OUTPUT_FILE" \
    --name "my-app" \
    --version "1.0.0" \
    --author "Security Team" \
    --supplier "Acme Inc" \
    --context "post-build"
  [ "$status" -eq 0 ]

  [ "$(jq -r '.metadata.component.name' "$OUTPUT_FILE")" = "my-app" ]
  [ "$(jq -r '.metadata.component.version' "$OUTPUT_FILE")" = "1.0.0" ]
  [ "$(jq -r '.metadata.authors[0].name' "$OUTPUT_FILE")" = "Security Team" ]
  [ "$(jq -r '.metadata.supplier.name' "$OUTPUT_FILE")" = "Acme Inc" ]
  [ "$(jq -r '.metadata.properties[] | select(.name=="cisa:generationContext").value' "$OUTPUT_FILE")" = "post-build" ]
}

@test "enrich-cisa: defaults generation-context to post-build when omitted" {
  run "$SCRIPT" \
    --input "$INPUT_FILE" \
    --output "$OUTPUT_FILE" \
    --name "my-app" \
    --version "1.0.0" \
    --author "Security Team"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.metadata.properties[] | select(.name=="cisa:generationContext").value' "$OUTPUT_FILE")" = "post-build" ]
}

@test "enrich-cisa: does not add a supplier object when --supplier is omitted" {
  run "$SCRIPT" \
    --input "$INPUT_FILE" \
    --output "$OUTPUT_FILE" \
    --name "my-app" \
    --version "1.0.0" \
    --author "Security Team"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.metadata.supplier // "null"' "$OUTPUT_FILE")" = "null" ]
}

@test "enrich-cisa: preserves existing components array untouched" {
  run "$SCRIPT" \
    --input "$INPUT_FILE" \
    --output "$OUTPUT_FILE" \
    --name "my-app" \
    --version "1.0.0" \
    --author "Security Team"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.components[0].name' "$OUTPUT_FILE")" = "example-lib" ]
}

@test "enrich-cisa: running twice does not duplicate the author or the cisa property" {
  "$SCRIPT" --input "$INPUT_FILE" --output "$OUTPUT_FILE" --name "my-app" --version "1.0.0" --author "Security Team" --context "post-build"
  run "$SCRIPT" --input "$OUTPUT_FILE" --output "$OUTPUT_FILE" --name "my-app" --version "1.0.0" --author "Security Team" --context "post-build"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.metadata.authors | length' "$OUTPUT_FILE")" -eq 1 ]
  [ "$(jq -r '[.metadata.properties[] | select(.name=="cisa:generationContext")] | length' "$OUTPUT_FILE")" -eq 1 ]
}

@test "enrich-cisa: fails with a clear error when --input file does not exist" {
  run "$SCRIPT" --input "/no/such/file.json" --output "$OUTPUT_FILE" --name "my-app" --version "1.0.0" --author "Security Team"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]]
}

@test "enrich-cisa: fails with a clear error when --input file is not valid JSON" {
  bad_input="$(mktemp)"
  echo "{not valid json" > "$bad_input"
  run "$SCRIPT" --input "$bad_input" --output "$OUTPUT_FILE" --name "my-app" --version "1.0.0" --author "Security Team"
  rm -f "$bad_input"
  [ "$status" -ne 0 ]
  [[ "$output" == *"valid JSON"* ]]
}

@test "enrich-cisa: fails with a clear error when required --name is missing" {
  run "$SCRIPT" --input "$INPUT_FILE" --output "$OUTPUT_FILE" --version "1.0.0" --author "Security Team"
  [ "$status" -ne 0 ]
  [[ "$output" == *"--name"* ]]
}
