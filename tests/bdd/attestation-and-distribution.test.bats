#!/usr/bin/env bats
# Acceptance tests for the attestation/GHCR/release-upload scenarios in
# features/package-distribution.feature.
#
# These three scenarios depend on live external services (Sigstore
# signing via GitHub's OIDC token, a real GHCR registry, the GitHub
# Releases API) that cannot be exercised in an offline unit/BDD run.
# Instead, these tests assert on the actual wiring in action.yml: the
# right step exists, is gated by the right input, and is invoked
# against the right target — i.e. that running the composite action
# with these inputs *would* do what the scenario describes.

setup() {
  ACTION_YML="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)/action.yml"
}

parse_step() {
  python3 - "$ACTION_YML" "$1" <<'EOF'
import sys, yaml
path, needle = sys.argv[1], sys.argv[2]
doc = yaml.safe_load(open(path))
for step in doc["runs"]["steps"]:
    blob = yaml.dump(step)
    if needle in blob:
        print(blob)
        sys.exit(0)
sys.exit(1)
EOF
}

@test "Scenario: GitHub Artifact Attestation Enabled" {
  # Given a valid CISA-compliant "sbom.json"
  # When the action input "attest" is set to "true"
  step=$(parse_step "actions/attest-sbom")

  # Then the action executes "actions/attest-sbom" targeting "sbom.json"
  [ -n "$step" ]
  [[ "$step" == *"inputs.attest == 'true'"* ]]
  [[ "$step" == *"cisa-enrich.outputs.sbom-path"* ]]
}

@test "Scenario: Opt-In Container Registry Attachment (GHCR)" {
  # Given a built OCI container image, when attach-ghcr=true, target=the image
  step=$(parse_step "cosign attach sbom")

  # Then "cosign attach sbom" is invoked against the target
  [ -n "$step" ]
  [[ "$step" == *"inputs.attach-ghcr == 'true'"* ]]
  [[ "$step" == *"inputs.target"* ]]
}

@test "Scenario: Attach SBOM Asset to Existing GitHub Release" {
  # Given a published release, when attach-release=true, release-tag=v2.0.0
  step=$(parse_step "gh release upload")

  # Then the asset "cisa-sbom.json" is uploaded to the release tag
  [ -n "$step" ]
  [[ "$step" == *"inputs.attach-release == 'true'"* ]]
  [[ "$step" == *"cisa-sbom.json"* ]]
}
