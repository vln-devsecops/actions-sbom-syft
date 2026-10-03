#!/usr/bin/env bats
# Acceptance tests for features/self-isolation.feature.
#
# These assert on action.yml's actual wiring: a composite action's `run:`
# steps execute with the consumer's checkout (github.workspace) as the
# working directory by default, and the action's own repo content lives
# in a separate github.action_path. The guarantee that this action scans
# only the consumer's workspace rests entirely on action.yml never
# blurring that boundary — so these tests parse and assert on the real
# step definitions rather than running syft (which needs the actual
# network-fetched binary and a real target repo; see the
# vln-devsecops/node-vlinder-auth integration test for that).

setup() {
  ACTION_YML="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)/action.yml"
}

get_step() {
  python3 - "$ACTION_YML" "$1" <<'EOF'
import sys, yaml
path, name = sys.argv[1], sys.argv[2]
doc = yaml.safe_load(open(path))
for step in doc["runs"]["steps"]:
    if step.get("name") == name:
        print(step.get("run", ""))
        sys.exit(0)
sys.exit(1)
EOF
}

all_steps_raw() {
  python3 - "$ACTION_YML" <<'EOF'
import sys, yaml
doc = yaml.safe_load(open(sys.argv[1]))
for step in doc["runs"]["steps"]:
    print(f"=== {step.get('name')} ===")
    print(step.get("run", ""))
    print(f"working-directory: {step.get('working-directory', '')}")
EOF
}

@test "Scenario: Syft scans only the caller's workspace, never the action's own path" {
  step=$(get_step "Generate Base CycloneDX SBOM")
  [ -n "$step" ]

  # invokes syft against "$TARGET" only
  [[ "$step" == *'syft "$TARGET"'* ]]

  # does not reference github.action_path anywhere in this step
  [[ "$step" != *"github.action_path"* ]]
}

@test "Scenario: Syft's own binary is installed outside the consumer's workspace" {
  step=$(get_step "Install Syft")
  [ -n "$step" ]

  [[ "$step" == *"github.action_path"* ]]
  [[ "$step" == *'bin_dir="${{ github.action_path }}/.bin"'* ]]
  [[ "$step" == *"GITHUB_PATH"* ]]
}

@test "Scenario: No step changes its working directory to the action's own checkout" {
  all_steps=$(all_steps_raw)

  # no step sets working-directory under github.action_path
  ! echo "$all_steps" | grep -q "working-directory:.*github.action_path"

  # no run command cd's into github.action_path
  ! echo "$all_steps" | grep -Eq 'cd ["\x27]?\$\{\{ *github\.action_path'
}

@test "Scenario: Version resolution runs against the caller's repository, not this one" {
  step=$(get_step "Resolve Application Version")
  [ -n "$step" ]

  # invokes the script with no -C override
  [[ "$step" != *" -C "* ]]

  # and the step itself sets no working-directory override
  wd=$(python3 - "$ACTION_YML" <<'EOF'
import sys, yaml
doc = yaml.safe_load(open(sys.argv[1]))
for step in doc["runs"]["steps"]:
    if step.get("name") == "Resolve Application Version":
        print(step.get("working-directory", ""))
EOF
)
  [ -z "$wd" ]
}
