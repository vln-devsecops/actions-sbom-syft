#!/usr/bin/env bats
# Acceptance test for features/corner-cases.feature,
# Scenario: Invalid Target Handled Gracefully.
#
# action.yml's "Validate Target" step runs scripts/validate-target.sh
# against the raw `target` input before anything else; this test
# exercises that same script, which is the sole enforcement point for
# this scenario's Then clause.

setup() {
  SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../scripts" && pwd)/validate-target.sh"
}

@test "Scenario: Invalid Target Handled Gracefully" {
  # Given a non-existent directory or target path "path/to/nonexistent"
  target="path/to/nonexistent"

  # When the SBOM action runs with target=path/to/nonexistent, source-name=failing-service
  run "$SCRIPT" "$target"

  # Then the action should exit with code 1
  [ "$status" -eq 1 ]

  # And an error message containing "target path does not exist" should be logged
  [[ "$output" == *"target path does not exist"* ]]
}
