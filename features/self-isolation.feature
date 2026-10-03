Feature: Self-Isolation When Used as a GitHub Action
  As a DevSecOps Engineer installing this action in a consumer repository
  I want the action to scan only the consumer's own workspace
  So that the generated SBOM reflects the consumer's dependencies, never
  this action's own scripts, test tooling, or installed Syft binary.

  Background:
    When this action is referenced as `uses: vln-devsecops/actions-sbom-syft@...`
    from another repository's workflow, GitHub Actions checks the action's own
    repository out into a separate directory (`github.action_path`), distinct
    from the consumer's checkout (`github.workspace`, the default working
    directory for every `run:` step). Nothing in action.yml should blur that
    boundary.

  Scenario: Syft scans only the caller's workspace, never the action's own path
    Given action.yml's "Generate Base CycloneDX SBOM" step
    When the step's run command is inspected
    Then it invokes syft against "$TARGET" (sourced from the target input) only
    And it does not reference "github.action_path" anywhere in that command

  Scenario: Syft's own binary is installed outside the consumer's workspace
    Given action.yml's "Install Syft" step
    When the step's run command is inspected
    Then the binary is written under a directory derived from "github.action_path"
    And it is made available via GITHUB_PATH rather than being copied into the
      current working directory

  Scenario: No step changes its working directory to the action's own checkout
    Given the full list of steps in action.yml
    When each step's "run" block and "working-directory" field are inspected
    Then no step sets "working-directory" to a path under "github.action_path"
    And no step's run command "cd"s into "github.action_path" before invoking
      syft, the version-resolution script, or the enrichment script

  Scenario: Version resolution runs against the caller's repository, not this one
    Given action.yml's "Resolve Application Version" step
    When the step's run command is inspected
    Then it invokes resolve-version.sh with no "-C" or working-directory
      override pointing at "github.action_path", so `git describe` (its
      fallback) sees the caller's own tags, never this action's release tags

  Scenario: The enriched SBOM path is computed from the workspace
    Given action.yml's "Enrich Metadata for CISA Compliance" step
    When the step's run command is inspected
    Then the "sbom-path" output is derived from "$(pwd)", not "github.action_path"
    And the step sets no working-directory override that would change what
      "pwd" means for it

  Scenario: GHCR attachment and package embedding never leak the action's own path
    Given action.yml's "Attach to OCI Image in GHCR" and
      "Embed SBOM in Package Payload" steps
    When each step's run command is inspected
    Then the GHCR step never references "github.action_path"
    And the package-embed step references "github.action_path" exactly once,
      only to locate its own attach-package.sh script, never as a data path

  Scenario: Sunshine's own files are installed outside the consumer's workspace
    Given action.yml's "Install Sunshine" step
    When the step's run command is inspected
    Then sunshine.py is written under a directory derived from
      "github.action_path", never into the current working directory

  Scenario: The human-readable report is generated from, and written to, the workspace
    Given action.yml's "Generate Human-Readable SBOM Report" step
    When the step's run command is inspected
    Then "github.action_path" is referenced only to locate sunshine.py itself
    And the "report-path" output is derived from "$(pwd)", not "github.action_path"

  Scenario: Uploading the human-readable report never references the action's own path
    Given action.yml's "Upload Human-Readable SBOM Report" step
    When the step is inspected
    Then it never references "github.action_path"
