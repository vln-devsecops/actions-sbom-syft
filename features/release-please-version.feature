Feature: Automatic Version Extraction via Release-Please
  As a Release Manager
  I want the action to automatically infer component versions from release-please manifests
  So that I do not have to manually pass version parameters in CI/CD pipelines.

  Scenario: Infer Version from Manifest File
    Given a file ".release-please-manifest.json" containing:
      """
      {
        ".": "1.8.2",
        "packages/service-a": "0.4.1"
      }
      """
    When the SBOM action runs with inputs:
      | input               | value                         |
      | source-name         | core-service                  |
      | source-version      |                                |
      | release-please-file | .release-please-manifest.json |
    Then the action output "resolved-version" should equal "1.8.2"
    And the SBOM metadata version should equal "1.8.2"

  Scenario: Explicit Version Overrides Release-Please Manifest
    Given a file ".release-please-manifest.json" containing:
      """
      { ".": "1.8.2" }
      """
    When the SBOM action runs with inputs:
      | input          | value |
      | source-version | 3.0.0 |
    Then the action output "resolved-version" should equal "3.0.0"

  Scenario: Release-Please File Missing with Git Fallback
    Given no ".release-please-manifest.json" exists in the repository
    And the git repository has tag "v1.4.0" at HEAD
    When the SBOM action runs with inputs:
      | input          | value      |
      | source-name    | tagged-app |
      | source-version |            |
    Then the action output "resolved-version" should equal "1.4.0"
    And the JSON property ".metadata.component.version" in "sbom.json" should equal "1.4.0"
