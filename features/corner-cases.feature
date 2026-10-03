Feature: Corner cases
  As a DevSecOps Engineer
  I want the action to fail fast and clearly on invalid configuration
  So that CI pipelines surface misconfiguration instead of producing a
  silently-wrong or missing SBOM.

  Scenario: Invalid Target Handled Gracefully
    Given a non-existent directory or target path "path/to/nonexistent"
    When the SBOM action runs with inputs:
      | input       | value               |
      | target      | path/to/nonexistent |
      | source-name | failing-service     |
    Then the action should exit with code 1
    And an error message containing "target path does not exist" should be logged
