#!/usr/bin/env bats
# Acceptance tests for features/release-please-version.feature.

setup() {
  RESOLVE_SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../scripts" && pwd)/resolve-version.sh"
  ENRICH_SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../scripts" && pwd)/enrich-cisa.sh"
  FIXTURE_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../fixtures" && pwd)"
  WORKDIR="$(mktemp -d)"
  cd "$WORKDIR"
}

teardown() {
  rm -rf "$WORKDIR"
}

@test "Scenario: Infer Version from Manifest File" {
  # Given a file ".release-please-manifest.json" containing the root/nested entries
  cat >.release-please-manifest.json <<'EOF'
{
  ".": "1.8.2",
  "packages/service-a": "0.4.1"
}
EOF

  # When the SBOM action runs with source-name=core-service, source-version empty
  run "$RESOLVE_SCRIPT" "" ".release-please-manifest.json" "."

  # Then the action output "resolved-version" should equal "1.8.2"
  [ "$status" -eq 0 ]
  [ "$output" = "1.8.2" ]
}

@test "Scenario: Explicit Version Overrides Release-Please Manifest" {
  # Given a file ".release-please-manifest.json" containing { ".": "1.8.2" }
  echo '{ ".": "1.8.2" }' >.release-please-manifest.json

  # When the SBOM action runs with source-version=3.0.0
  run "$RESOLVE_SCRIPT" "3.0.0" ".release-please-manifest.json" "."

  # Then the action output "resolved-version" should equal "3.0.0"
  [ "$status" -eq 0 ]
  [ "$output" = "3.0.0" ]
}

@test "Scenario: Release-Please File Missing with Git Fallback" {
  # Given no ".release-please-manifest.json" exists, and a git tag "v1.4.0" at HEAD
  git init -q
  git config user.email t@example.com
  git config user.name tester
  git commit -q --allow-empty -m init
  git tag v1.4.0

  # When the SBOM action runs with source-name=tagged-app, source-version empty
  resolved_version=$("$RESOLVE_SCRIPT" "" ".release-please-manifest.json" ".")

  # Then the action output "resolved-version" should equal "1.4.0"
  [ "$resolved_version" = "1.4.0" ]

  # And the JSON property ".metadata.component.version" in "sbom.json" should equal "1.4.0"
  run "$ENRICH_SCRIPT" \
    --input "${FIXTURE_DIR}/sample-syft-output.json" \
    --output sbom.json \
    --name "tagged-app" \
    --version "$resolved_version" \
    --author "ci"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.metadata.component.version' sbom.json)" = "1.4.0" ]
}
